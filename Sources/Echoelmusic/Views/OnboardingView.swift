import SwiftUI

// MARK: - Onboarding View
// Max 3 Screens, skippable, Vaporwave aesthetic

struct OnboardingView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthKitManager: HealthKitManager

    // MARK: - State

    @State private var currentPage = 0
    @Binding var hasCompletedOnboarding: Bool

    // MARK: - Pages

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform.circle.fill",
            title: "Willkommen bei Echoelmusic",
            subtitle: "Dein Körper wird zur Musik",
            description: "Echoelmusic verwandelt deine Biometrie in lebendige Audio-Visuelle Erlebnisse. Herzfrequenz, HRV und Atmung steuern Sound und Visualisierungen.",
            color: VaporwaveColors.neonPink
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Biofeedback verbinden",
            subtitle: "Apple Watch oder Polar H10",
            description: "Für das beste Erlebnis verbinde eine Apple Watch für HRV-Daten oder einen Polar H10 für Echtzeit Beat-Sync.",
            color: VaporwaveColors.heartRate,
            requiresPermission: true
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Flow State erreichen",
            subtitle: "Entspannen. Atmen. Kreieren.",
            description: "Starte eine Session und beobachte wie dein Körper die Musik beeinflusst. Je höher deine Kohärenz, desto harmonischer der Sound.",
            color: VaporwaveColors.coherenceHigh
        )
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()

                    Button(action: completeOnboarding) {
                        Text("Überspringen")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, VaporwaveSpacing.md)
                .padding(.horizontal, VaporwaveSpacing.lg)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(for: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicators
                HStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? pages[index].color : VaporwaveColors.textTertiary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, VaporwaveSpacing.lg)

                // Action button
                actionButton
                    .padding(.horizontal, VaporwaveSpacing.xl)
                    .padding(.bottom, VaporwaveSpacing.xxl)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Page View

    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: VaporwaveSpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 150, height: 150)

                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundColor(page.color)
            }
            .neonGlow(color: page.color, radius: 25)

            // Title
            Text(page.title)
                .font(VaporwaveTypography.sectionTitle())
                .foregroundColor(VaporwaveColors.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(VaporwaveTypography.caption())
                .foregroundColor(page.color)
                .tracking(2)

            // Description
            Text(page.description)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VaporwaveSpacing.xl)

            // Permission button if needed
            if page.requiresPermission {
                permissionButton
                    .padding(.top, VaporwaveSpacing.md)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Permission Button

    private var permissionButton: some View {
        Button(action: requestHealthKitPermission) {
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: healthKitManager.isAuthorized ? "checkmark.circle.fill" : "heart.circle")
                    .font(.system(size: 20))

                Text(healthKitManager.isAuthorized ? "HealthKit verbunden" : "HealthKit erlauben")
                    .font(VaporwaveTypography.body())
            }
            .foregroundColor(.white)
            .padding(.horizontal, VaporwaveSpacing.xl)
            .padding(.vertical, VaporwaveSpacing.md)
            .background(
                Capsule()
                    .fill(healthKitManager.isAuthorized ? VaporwaveColors.success : VaporwaveColors.heartRate)
            )
        }
        .disabled(healthKitManager.isAuthorized)
        .neonGlow(color: healthKitManager.isAuthorized ? VaporwaveColors.success : VaporwaveColors.heartRate, radius: 10)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: {
            if currentPage < pages.count - 1 {
                withAnimation(VaporwaveAnimation.smooth) {
                    currentPage += 1
                }
            } else {
                completeOnboarding()
            }
        }) {
            HStack(spacing: VaporwaveSpacing.sm) {
                Text(currentPage < pages.count - 1 ? "Weiter" : "Los geht's")
                    .font(.system(size: 18, weight: .semibold))

                Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "sparkles")
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaporwaveSpacing.md)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                pages[currentPage].color,
                                pages[currentPage].color.opacity(0.7)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .neonGlow(color: pages[currentPage].color, radius: 15)
    }

    // MARK: - Actions

    private func requestHealthKitPermission() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } catch {
                print("⚠️ HealthKit authorization failed: \(error)")
            }
        }
    }

    private func completeOnboarding() {
        // Save completion state
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        hasCompletedOnboarding = true

        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
    var requiresPermission: Bool = false
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(HealthKitManager())
}
