//
//  FeatureTipView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Contextual feature tips and tooltips
//

import SwiftUI

struct FeatureTipView: View {
    let feature: OnboardingManager.Feature
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: feature.icon)
                    .foregroundColor(.blue)

                Text(feature.title)
                    .font(.headline)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Text(feature.description)
                .font(.body)
                .foregroundColor(.secondary)

            Button {
                OnboardingManager.shared.markFeatureAsSeen(feature)
                onDismiss()
            } label: {
                Text("Got It")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
}

// MARK: - Tooltip Modifier

extension View {
    /// Show a contextual tooltip for a feature
    func featureTip(
        _ feature: OnboardingManager.Feature,
        isPresented: Binding<Bool>,
        alignment: Alignment = .top
    ) -> some View {
        self.overlay(alignment: alignment) {
            if isPresented.wrappedValue {
                FeatureTipView(feature: feature) {
                    isPresented.wrappedValue = false
                }
                .transition(.scale.combined(with: .opacity))
                .padding()
            }
        }
        .animation(.spring(), value: isPresented.wrappedValue)
    }
}

// MARK: - Inline Tip View

struct InlineTip: View {
    let title: String
    let message: String
    let icon: String
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Usage Examples

/*
 USAGE EXAMPLES:

 1. Contextual Tooltip:

 struct RecordingView: View {
     @State private var showTip = false

     var body: some View {
         Button("Record") {
             // Start recording
         }
         .featureTip(.recording, isPresented: $showTip)
         .onAppear {
             if OnboardingManager.shared.shouldShowTip(for: .recording) {
                 showTip = true
             }
         }
     }
 }

 2. Inline Tip:

 struct EffectsView: View {
     @State private var showEffectTip = true

     var body: some View {
         VStack {
             InlineTip(
                 title: "New Feature!",
                 message: "Try Face Control to control effects with your expressions",
                 icon: "sparkles",
                 isPresented: $showEffectTip
             )

             // Effects list...
         }
     }
 }

 3. First-Time Feature Highlight:

 struct InstrumentPicker: View {
     @StateObject private var onboarding = OnboardingManager.shared

     var body: some View {
         // Show tip only if user hasn't seen instruments feature
         if !onboarding.hasSeenFeature(.instruments) {
             InlineTip(
                 title: "47 Instruments Available",
                 message: "Swipe to browse all professional instruments",
                 icon: "music.note",
                 isPresented: .constant(true)
             )
             .onAppear {
                 onboarding.markFeatureAsSeen(.instruments)
             }
         }
     }
 }
 */

// MARK: - Coach Mark View

struct CoachMarkView: View {
    let title: String
    let message: String
    let targetRect: CGRect
    let onNext: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // Highlight cutout (would need custom shape)

            // Instruction bubble
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack {
                    Button("Skip") {
                        onDismiss()
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("Next") {
                        onNext()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()
        }
    }
}

// MARK: - Welcome Back Banner

struct WelcomeBackBanner: View {
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "hand.wave.fill")
                        .foregroundColor(.yellow)

                    Text("Welcome back!")
                        .font(.headline)

                    Spacer()

                    Button {
                        withAnimation {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }

                Text("Ready to create more amazing music?")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Feature Discovery System

@MainActor
class FeatureDiscoveryManager: ObservableObject {
    @Published var pendingTips: [OnboardingManager.Feature] = []
    @Published var currentTip: OnboardingManager.Feature?

    func queueTip(_ feature: OnboardingManager.Feature) {
        guard OnboardingManager.shared.shouldShowTip(for: feature) else { return }
        guard !pendingTips.contains(feature) else { return }

        pendingTips.append(feature)
        showNextTipIfNeeded()
    }

    func showNextTipIfNeeded() {
        guard currentTip == nil else { return }
        guard let next = pendingTips.first else { return }

        currentTip = next
        pendingTips.removeFirst()
    }

    func dismissCurrentTip() {
        if let current = currentTip {
            OnboardingManager.shared.markFeatureAsSeen(current)
        }
        currentTip = nil
        showNextTipIfNeeded()
    }
}

// MARK: - Preview

#Preview("Feature Tip") {
    ZStack {
        Color.gray.opacity(0.3)

        FeatureTipView(feature: .faceControl) {
            print("Dismissed")
        }
        .padding()
    }
}

#Preview("Inline Tip") {
    InlineTip(
        title: "New Feature!",
        message: "Try Face Control to control effects with your expressions",
        icon: "sparkles",
        isPresented: .constant(true)
    )
    .padding()
}
