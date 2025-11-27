//
//  PhotosensitivityWarningView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  User-facing photosensitivity safety warning dialog
//

import SwiftUI

/// Photosensitivity safety warning dialog
///
/// **MUST** be shown before enabling any visual effects that could flash or change rapidly.
/// Implements informed consent for WCAG 2.3.1 compliance.
struct PhotosensitivityWarningView: View {
    @ObservedObject var manager: PhotosensitivityManager

    @Environment(\.dismiss) private var dismiss

    @State private var hasScrolledToBottom = false
    @State private var acknowledgeChecked = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 20)

                    Text("Photosensitivity Warning")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("REQUIRED SAFETY INFORMATION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.2))
                        )
                }
                .padding(.bottom, 20)

                // Scrollable content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            warningContent

                            // Bottom marker for scroll detection
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

                // Acknowledgment checkbox
                Button(action: {
                    acknowledgeChecked.toggle()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: acknowledgeChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 24))
                            .foregroundColor(acknowledgeChecked ? .green : .gray)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("I have read and understood the warnings")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)

                            Text("I do not have any contraindicated conditions")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.2))
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
                        manager.declineWarning()
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
                        manager.acknowledgeWarning()
                        dismiss()
                    }) {
                        Text("I Acknowledge")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(acknowledgeChecked ? Color.green : Color.gray.opacity(0.3))
                            )
                    }
                    .disabled(!acknowledgeChecked)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .interactiveDismissDisabled()  // Cannot dismiss without choosing
    }

    // MARK: - Warning Content

    private var warningContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main warning
            warningSection(
                title: "⚠️ DO NOT USE IF YOU HAVE:",
                items: [
                    "Epilepsy or seizure disorders",
                    "Photosensitivity or light sensitivity",
                    "Family history of epilepsy",
                    "Seizures triggered by light patterns or flashing lights"
                ],
                color: .red
            )

            Divider()
                .background(Color.white.opacity(0.2))

            // Symptoms
            warningSection(
                title: "🚨 STOP IMMEDIATELY IF YOU EXPERIENCE:",
                items: [
                    "Lightheadedness or dizziness",
                    "Altered vision or eye discomfort",
                    "Involuntary movements or twitching",
                    "Disorientation or confusion",
                    "Loss of awareness or consciousness"
                ],
                color: .orange
            )

            Divider()
                .background(Color.white.opacity(0.2))

            // Safety features
            warningSection(
                title: "✓ BUILT-IN SAFETY FEATURES:",
                items: [
                    "WCAG 2.3.1 compliant (max 3 flashes/second)",
                    "Epilepsy risk zone blocked (15-25 Hz)",
                    "Respects system 'Reduce Motion' setting",
                    "Emergency disable: Triple-tap screen",
                    "Automatic brightness limiting"
                ],
                color: .green
            )

            Divider()
                .background(Color.white.opacity(0.2))

            // Medical disclaimer
            VStack(alignment: .leading, spacing: 8) {
                Text("⚕️ MEDICAL DISCLAIMER")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)

                Text("This app is for entertainment and research purposes only. It is not a medical device and does not diagnose, treat, or prevent any medical condition. Consult a physician before use if you have any concerns.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Legal
            VStack(alignment: .leading, spacing: 8) {
                Text("📄 LIABILITY")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)

                Text("Use of visual effects is at your own risk. By acknowledging this warning, you accept full responsibility and agree to hold Echoelmusic harmless from any adverse effects.")
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
}

// MARK: - Preview

#if DEBUG
struct PhotosensitivityWarningView_Previews: PreviewProvider {
    static var previews: some View {
        PhotosensitivityWarningView(manager: .shared)
    }
}
#endif
