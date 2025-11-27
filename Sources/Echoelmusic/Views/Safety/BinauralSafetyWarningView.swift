//
//  BinauralSafetyWarningView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  User-facing binaural beats safety warning dialog
//

import SwiftUI

/// Binaural beats safety warning dialog
///
/// **MUST** be shown before enabling any binaural beat sessions.
/// Implements informed consent for medical safety.
struct BinauralSafetyWarningView: View {
    @ObservedObject var manager: BinauralSafetyManager

    @Environment(\.dismiss) private var dismiss

    @State private var hasScrolledToBottom = false
    @State private var acknowledgeChecked = false
    @State private var noContraindicationsChecked = false
    @State private var over18Checked = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 20)

                    Text("Binaural Beats Warning")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("MEDICAL SAFETY INFORMATION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.2))
                        )

                    Text("Affects brainwave patterns • Altered states • Medical contraindications")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 20)

                // Scrollable content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            warningContent

                            // Bottom marker
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                                .onAppear {
                                    hasScrolledToBottom = true
                                }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    .frame(maxHeight: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .padding(.horizontal, 20)
                }

                // Acknowledgment checkboxes
                VStack(spacing: 12) {
                    checkboxRow(
                        checked: $acknowledgeChecked,
                        text: "I have read and understood all warnings and contraindications"
                    )

                    checkboxRow(
                        checked: $noContraindicationsChecked,
                        text: "I do NOT have any of the listed contraindicated conditions"
                    )

                    checkboxRow(
                        checked: $over18Checked,
                        text: "I am 18 years or older (or have parental consent)"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .disabled(!hasScrolledToBottom)
                .opacity(hasScrolledToBottom ? 1.0 : 0.5)

                if !hasScrolledToBottom {
                    Text("Scroll to bottom to continue")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }

                // Action buttons
                HStack(spacing: 16) {
                    // Decline button
                    Button(action: {
                        manager.declineWarnings()
                        dismiss()
                    }) {
                        Text("I Decline")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                            )
                    }

                    // Accept button
                    Button(action: {
                        manager.acknowledgeWarnings()
                        dismiss()
                    }) {
                        Text("I Acknowledge & Accept")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(allChecked ? Color.green : Color.gray.opacity(0.3))
                            )
                    }
                    .disabled(!allChecked)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Computed

    private var allChecked: Bool {
        acknowledgeChecked && noContraindicationsChecked && over18Checked
    }

    // MARK: - Warning Content

    private var warningContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main warning
            warningSection(
                title: "⚠️ DO NOT USE IF YOU HAVE:",
                items: [
                    "Epilepsy, seizure disorders, or convulsions",
                    "Heart conditions, pacemakers, or arrhythmia",
                    "Pregnancy or breastfeeding",
                    "Mental health conditions (without medical supervision)",
                    "Sound sensitivity or hearing disorders",
                    "History of adverse reactions to audio stimulation"
                ],
                color: .red
            )

            Divider().background(Color.white.opacity(0.2))

            // Effects
            warningSection(
                title: "⚡ POTENTIAL EFFECTS:",
                items: [
                    "Altered states of consciousness",
                    "Deep relaxation or drowsiness",
                    "Changes in perception or awareness",
                    "Emotional shifts or releases",
                    "Temporary disorientation",
                    "Vivid imagery or sensations"
                ],
                color: .orange
            )

            Divider().background(Color.white.opacity(0.2))

            // Stop if experiencing
            warningSection(
                title: "🚨 STOP IMMEDIATELY IF YOU EXPERIENCE:",
                items: [
                    "Dizziness, vertigo, or disorientation",
                    "Nausea or severe headache",
                    "Anxiety, panic, or fear",
                    "Unusual sensations or tremors",
                    "Visual disturbances",
                    "ANY discomfort or distress"
                ],
                color: .red
            )

            Divider().background(Color.white.opacity(0.2))

            // Do not use while
            warningSection(
                title: "🚫 DO NOT USE WHILE:",
                items: [
                    "Driving or operating machinery",
                    "Performing tasks requiring full alertness",
                    "Under influence of medications/alcohol/substances",
                    "In unsafe or unfamiliar environments"
                ],
                color: .orange
            )

            Divider().background(Color.white.opacity(0.2))

            // Safety features
            warningSection(
                title: "✓ BUILT-IN SAFETY FEATURES:",
                items: [
                    "20-minute maximum session time",
                    "Epilepsy risk frequencies blocked (15-25 Hz)",
                    "Automatic headphone detection",
                    "Session monitoring and warnings",
                    "Emergency stop available"
                ],
                color: .green
            )

            Divider().background(Color.white.opacity(0.2))

            // Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("📋 REQUIREMENTS FOR SAFE USE")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)

                Text("• MUST use headphones (binaural effect requires stereo isolation)\n• Use in quiet, comfortable environment\n• Sit or lie down in safe position\n• Have water nearby\n• Do not exceed 20-minute sessions\n• Take breaks between sessions")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }

            Divider().background(Color.white.opacity(0.2))

            // Medical disclaimer
            VStack(alignment: .leading, spacing: 8) {
                Text("⚕️ MEDICAL DISCLAIMER")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)

                Text("Binaural beats are for entertainment and research purposes ONLY. This is NOT a medical device, treatment, or therapy. It does not diagnose, treat, cure, or prevent any medical condition. Effects vary by individual. Consult a physician before use if you have any medical conditions or concerns.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.2))

            // Scientific basis
            VStack(alignment: .leading, spacing: 8) {
                Text("🔬 SCIENTIFIC BASIS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)

                Text("Binaural beats work by presenting slightly different frequencies to each ear, causing the brain to perceive a third \"beat\" frequency. This phenomenon can induce brainwave entrainment to target states (delta, theta, alpha, beta, gamma).\n\nResearch: Oster (1973), Wahbeh et al. (2007), Lane et al. (1998)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.2))

            // Liability
            VStack(alignment: .leading, spacing: 8) {
                Text("📄 LIABILITY & RESPONSIBILITY")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)

                Text("Use of binaural beats is AT YOUR OWN RISK. By acknowledging this warning, you accept FULL RESPONSIBILITY for any effects or consequences and agree to HOLD Echoelmusic HARMLESS from any adverse effects, injuries, or damages arising from use.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func warningSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(color)
                        Text(item)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func checkboxRow(checked: Binding<Bool>, text: String) -> some View {
        Button(action: {
            checked.wrappedValue.toggle()
        }) {
            HStack(spacing: 12) {
                Image(systemName: checked.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(checked.wrappedValue ? .green : .gray)

                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BinauralSafetyWarningView_Previews: PreviewProvider {
    static var previews: some View {
        BinauralSafetyWarningView(manager: .shared)
    }
}
#endif
