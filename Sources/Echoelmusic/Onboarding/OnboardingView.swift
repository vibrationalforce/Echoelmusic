//
//  OnboardingView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Main onboarding flow
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: onboardingManager.progressPercentage)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                // Current step view
                TabView(selection: $onboardingManager.currentStep) {
                    ForEach(OnboardingManager.OnboardingStep.allCases, id: \.self) { step in
                        stepView(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: onboardingManager.currentStep)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Step Views

    @ViewBuilder
    private func stepView(for step: OnboardingManager.OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeScreen()
        case .accountCreation:
            AccountCreationScreen()
        case .permissions:
            PermissionsScreen()
        case .quickTutorial:
            QuickTutorialScreen()
        case .firstProject:
            FirstProjectScreen()
        case .completed:
            CompletionScreen()
        }
    }
}

// MARK: - Welcome Screen

struct WelcomeScreen: View {
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo/Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 120))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            VStack(spacing: 12) {
                Text("Welcome to Echoelmusic")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Professional music production & gig platform")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Key features
            VStack(alignment: .leading, spacing: 16) {
                FeatureHighlight(
                    icon: "music.note.list",
                    title: "47 Instruments & 77 Effects",
                    description: "Professional-grade sounds"
                )

                FeatureHighlight(
                    icon: "face.smiling",
                    title: "Face Control",
                    description: "Control effects with expressions"
                )

                FeatureHighlight(
                    icon: "briefcase",
                    title: "Find Gigs",
                    description: "Get hired through EoelWork"
                )
            }
            .padding(.horizontal)

            Spacer()

            // Continue button
            Button {
                onboardingManager.nextStep()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Account Creation Screen

struct AccountCreationScreen: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var email = ""
    @State private var isCreatingAccount = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            VStack(spacing: 8) {
                Text("Create Your Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sync projects across all your devices")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "icloud", text: "Cloud sync")
                BenefitRow(icon: "arrow.triangle.2.circlepath", text: "Backup & restore")
                BenefitRow(icon: "infinity", text: "Access from anywhere")
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Sign-in options
            VStack(spacing: 12) {
                Button {
                    // Sign in with Apple
                    Task {
                        await signInWithApple()
                    }
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Continue with Apple")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
                }

                Button {
                    // Sign in with Google
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }

                Button("Skip for Now") {
                    onboardingManager.skipStep()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func signInWithApple() async {
        isCreatingAccount = true
        // Implement Sign in with Apple
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isCreatingAccount = false
        onboardingManager.nextStep()
    }
}

// MARK: - Permissions Screen

struct PermissionsScreen: View {
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            // Title
            VStack(spacing: 8) {
                Text("Enable Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose which features you'd like to use")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Permission cards
            ScrollView {
                VStack(spacing: 16) {
                    PermissionCard(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Record audio and create music",
                        required: true
                    )

                    PermissionCard(
                        icon: "face.smiling",
                        title: "Camera (Face Control)",
                        description: "Control effects with facial expressions",
                        required: false
                    )

                    PermissionCard(
                        icon: "heart.fill",
                        title: "Health Data",
                        description: "Adaptive audio based on biometrics",
                        required: false
                    )

                    PermissionCard(
                        icon: "location.fill",
                        title: "Location (EoelWork)",
                        description: "Find gigs near you",
                        required: false
                    )
                }
                .padding(.horizontal)
            }

            Spacer()

            // Info text
            Text("You can change these anytime in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Continue button
            Button {
                onboardingManager.nextStep()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Quick Tutorial Screen

struct QuickTutorialScreen: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var currentPage = 0

    let tutorials = [
        TutorialPage(
            icon: "record.circle",
            title: "Record",
            description: "Tap the record button to start capturing audio"
        ),
        TutorialPage(
            icon: "waveform",
            title: "Add Effects",
            description: "Choose from 77 professional effects"
        ),
        TutorialPage(
            icon: "square.and.arrow.up",
            title: "Export",
            description: "Share your creation with the world"
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Tutorial pager
            TabView(selection: $currentPage) {
                ForEach(tutorials.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Image(systemName: tutorials[index].icon)
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        VStack(spacing: 12) {
                            Text(tutorials[index].title)
                                .font(.title)
                                .fontWeight(.bold)

                            Text(tutorials[index].description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .frame(height: 300)

            Spacer()

            // Buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(currentPage == tutorials.count - 1 ? "Done" : "Next") {
                    if currentPage == tutorials.count - 1 {
                        onboardingManager.nextStep()
                    } else {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            Button("Skip Tutorial") {
                onboardingManager.skipStep()
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
    }
}

// MARK: - First Project Screen

struct FirstProjectScreen: View {
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Create Your First Project")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Let's record your first track together")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onboardingManager.completeOnboarding()
                // Navigate to main app with new project
            } label: {
                Text("Create Project")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Button("I'll Do This Later") {
                onboardingManager.completeOnboarding()
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
    }
}

// MARK: - Completion Screen

struct CompletionScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 120))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You're ready to create amazing music")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Start Creating")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Supporting Views

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
                .font(.body)
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let required: Bool
    @State private var isEnabled = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if required {
                        Text("Required")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !required {
                Toggle("", isOn: $isEnabled)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct TutorialPage {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
