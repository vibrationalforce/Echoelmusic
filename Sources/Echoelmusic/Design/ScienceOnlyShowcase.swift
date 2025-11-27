//
//  ScienceOnlyShowcase.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Science-Only Audio-Visual Research Tool
//  Pure peer-reviewed research - NO health claims
//  User assumes all responsibility for use
//

import SwiftUI

/// MEDICAL DISCLAIMER - CRITICAL
/// This tool presents peer-reviewed research ONLY. It makes NO health claims.
/// NOT intended to diagnose, treat, cure, or prevent any disease.
/// NOT a substitute for professional medical advice.
/// Consult physician before use, especially with:
/// - Epilepsy, seizure disorders, photosensitivity
/// - Bipolar disorder, psychiatric conditions
/// - Eye diseases, retinal conditions
/// - Pregnancy, medications
/// User assumes ALL RESPONSIBILITY for use.

struct ScienceOnlyShowcase: View {
    @StateObject private var therapy = ScienceBasedTherapy.shared
    @StateObject private var audioGen = AudioTherapyGenerator.shared
    @State private var selectedMode: ScienceBasedTherapy.TherapyMode = .circadianRegulation
    @State private var showDisclaimer = true
    @State private var userAcceptedResponsibility = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showDisclaimer && !userAcceptedResponsibility {
                disclaimerView
            } else {
                mainInterface
            }
        }
    }

    // MARK: - Medical Disclaimer

    var disclaimerView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("RESEARCH TOOL - NOT MEDICAL DEVICE")
                .font(.title.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 16) {
                Text("CRITICAL DISCLAIMERS:")
                    .font(.headline)
                    .foregroundColor(.orange)

                disclaimerText("NO HEALTH CLAIMS: Presents peer-reviewed research only")
                disclaimerText("NOT FOR MEDICAL USE: Not intended to diagnose, treat, cure, or prevent disease")
                disclaimerText("NOT MEDICAL ADVICE: Consult physician before use")
                disclaimerText("USER RESPONSIBILITY: You assume ALL risk and responsibility")

                Text("CONTRAINDICATIONS - DO NOT USE IF YOU HAVE:")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.top, 8)

                disclaimerText("Epilepsy, seizure disorders, or photosensitivity")
                disclaimerText("Bipolar disorder or psychiatric conditions")
                disclaimerText("Eye diseases, retinal conditions, macular degeneration")
                disclaimerText("Are pregnant or taking medications")
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)

            Button {
                userAcceptedResponsibility = true
            } label: {
                Text("I ACCEPT FULL RESPONSIBILITY - PROCEED FOR RESEARCH ONLY")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                .shadow(radius: 20)
        )
        .padding(32)
    }

    func disclaimerText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Main Interface

    var mainInterface: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("AUDIO-VISUAL RESEARCH TOOL")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text("Peer-Reviewed Research Explorer")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Research Mode Selector
                researchModeSelector

                // Current Research Details
                currentResearchCard

                // Audio-Visual Control
                audioVisualControl

                // Research References
                researchReferencesCard

                // Safety Information
                safetyCard
            }
            .padding()
        }
    }

    // MARK: - Research Mode Selector

    var researchModeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RESEARCH AREAS")
                .font(.headline)
                .foregroundColor(.cyan)

            ForEach(ScienceBasedTherapy.TherapyMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                    therapy.setMode(mode)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(mode.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()

                                // Evidence badge
                                evidenceBadge(mode.clinicalEvidence.level)

                                // FDA badge
                                if mode.clinicalEvidence.fdaApproved {
                                    Text("FDA")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green)
                                        .cornerRadius(4)
                                }
                            }

                            Text(mode.wavelengthRange)
                                .font(.caption)
                                .foregroundColor(.cyan)

                            Text("Studies: \(mode.clinicalEvidence.studies.count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }

                        Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedMode == mode ? .cyan : .gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(selectedMode == mode ? 0.15 : 0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedMode == mode ? Color.cyan : Color.white.opacity(0.1),
                                        lineWidth: selectedMode == mode ? 2 : 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
    }

    func evidenceBadge(_ level: ScienceBasedTherapy.ClinicalEvidence.EvidenceLevel) -> some View {
        Text(level.rawValue.uppercased())
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color)
            .cornerRadius(4)
    }

    // MARK: - Current Research Card

    var currentResearchCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RESEARCH DATA")
                    .font(.headline)
                    .foregroundColor(.cyan)

                Spacer()

                evidenceBadge(selectedMode.clinicalEvidence.level)
            }

            // Wavelength info
            HStack {
                Text("Wavelength:")
                    .foregroundColor(.gray)
                Text(selectedMode.wavelengthRange)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            }
            .font(.subheadline)

            // Frequency info (if applicable)
            if let freq = selectedMode.frequencyRange {
                HStack {
                    Text("Frequency:")
                        .foregroundColor(.gray)
                    Text(freq)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }

            Divider().background(Color.white.opacity(0.2))

            // Mechanism (pure science, no claims)
            VStack(alignment: .leading, spacing: 8) {
                Text("DOCUMENTED MECHANISM:")
                    .font(.caption.bold())
                    .foregroundColor(.orange)

                Text(selectedMode.clinicalEvidence.mechanism)
                    .font(.caption)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.2))

            // Contraindications
            if !selectedMode.clinicalEvidence.contraindications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONTRAINDICATIONS:")
                        .font(.caption.bold())
                        .foregroundColor(.red)

                    ForEach(selectedMode.clinicalEvidence.contraindications, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 4) {
                            Text("⚠️")
                                .font(.caption2)
                            Text(warning)
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
    }

    // MARK: - Audio-Visual Control

    var audioVisualControl: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AUDIO-VISUAL PARAMETERS")
                .font(.headline)
                .foregroundColor(.cyan)

            // Visual intensity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Visual Intensity")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f%%", therapy.visualIntensity * 100))
                        .foregroundColor(.cyan)
                        .fontWeight(.medium)
                }
                .font(.subheadline)

                Slider(value: $therapy.visualIntensity, in: 0...1)
                    .accentColor(.cyan)
            }

            // Audio type selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Type")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Picker("Audio Type", selection: $audioGen.audioType) {
                    Text("Binaural Beats").tag(AudioTherapyGenerator.AudioType.binauralBeats(carrier: 200))
                    Text("Isochronic Tones").tag(AudioTherapyGenerator.AudioType.isochronicTones)
                    Text("Monaural Beats").tag(AudioTherapyGenerator.AudioType.monauralBeats(carrier: 200))
                    Text("Pink Noise").tag(AudioTherapyGenerator.AudioType.pinkNoise)
                    Text("White Noise").tag(AudioTherapyGenerator.AudioType.whiteNoise)
                }
                .pickerStyle(.segmented)
            }

            // Audio volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Audio Volume")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f%%", audioGen.volume * 100))
                        .foregroundColor(.cyan)
                        .fontWeight(.medium)
                }
                .font(.subheadline)

                Slider(value: $audioGen.volume, in: 0...1)
                    .accentColor(.cyan)
            }

            Divider().background(Color.white.opacity(0.2))

            // Control buttons
            HStack(spacing: 16) {
                Button {
                    if therapy.isActive {
                        therapy.stop()
                        audioGen.stop()
                    } else {
                        therapy.start()
                        audioGen.start(frequency: getTargetFrequency())
                    }
                } label: {
                    HStack {
                        Image(systemName: therapy.isActive ? "stop.fill" : "play.fill")
                        Text(therapy.isActive ? "STOP" : "START")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(therapy.isActive ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Clinical protocol selector
                Menu {
                    ForEach(ScienceBasedTherapy.ClinicalProtocol.standardProtocols, id: \.name) { protocol in
                        Button(protocol.name) {
                            therapy.startProtocol(protocol)
                            audioGen.start(frequency: getTargetFrequency())
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("PROTOCOLS")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Session timer
            if let session = therapy.currentSession {
                HStack {
                    Text("Session:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(formatTime(session.remainingTime))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            }

            // Visual preview
            visualPreview
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
    }

    var visualPreview: some View {
        ZStack {
            Rectangle()
                .fill(therapy.currentColor)
                .opacity(therapy.visualIntensity)
                .frame(height: 100)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )

            if !therapy.isActive {
                Text("Visual Preview (inactive)")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.caption)
            }
        }
    }

    // MARK: - Research References

    var researchReferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PEER-REVIEWED RESEARCH")
                .font(.headline)
                .foregroundColor(.cyan)

            ForEach(selectedMode.clinicalEvidence.studies, id: \.self) { study in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.cyan)
                        .font(.caption)

                    Text(study)
                        .font(.caption)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if selectedMode.clinicalEvidence.fdaApproved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("FDA-cleared wavelength/application")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
    }

    // MARK: - Safety Card

    var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("SAFETY & RESPONSIBILITY")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                safetyPoint("Research tool only - NOT for medical use")
                safetyPoint("Consult physician before use")
                safetyPoint("Stop immediately if you experience discomfort")
                safetyPoint("User assumes ALL responsibility")
                safetyPoint("Not evaluated by FDA for medical claims")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    func safetyPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("⚠️")
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    // MARK: - Helpers

    func getTargetFrequency() -> Double {
        // Extract frequency from mode
        switch selectedMode {
        case .circadianRegulation: return 10.0
        case .eyeComfort: return 8.0
        case .photobiomodulation: return 0.0  // No audio
        case .seasonalAffective: return 10.0
        case .focusEnhancement: return 16.0
        case .stressReduction: return 10.0
        }
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Evidence Level Extension

extension ScienceBasedTherapy.ClinicalEvidence.EvidenceLevel {
    var color: Color {
        switch self {
        case .strong: return .green
        case .moderate: return .blue
        case .emerging: return .orange
        case .theoretical: return .gray
        }
    }
}

// MARK: - Preview

#Preview("Science-Only Showcase") {
    ScienceOnlyShowcase()
}
