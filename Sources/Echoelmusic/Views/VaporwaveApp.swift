import SwiftUI

// MARK: - Vaporwave App Root
// Die Hauptnavigation für das Vaporwave Palace

struct VaporwaveApp: View {

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var recordingEngine: RecordingEngine

    // MARK: - State

    @State private var selectedTab: Tab = .palace
    @State private var showSettings = false
    @State private var showOnboarding = false

    // MARK: - Tabs

    enum Tab: String, CaseIterable {
        case palace = "palace"
        case sessions = "sessions"
        case create = "create"
        case profile = "profile"

        var icon: String {
            switch self {
            case .palace: return "waveform.circle"
            case .sessions: return "clock.arrow.circlepath"
            case .create: return "plus.circle"
            case .profile: return "person.circle"
            }
        }

        var iconFilled: String {
            switch self {
            case .palace: return "waveform.circle.fill"
            case .sessions: return "clock.arrow.circlepath"
            case .create: return "plus.circle.fill"
            case .profile: return "person.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .palace: return "Palace"
            case .sessions: return "Sessions"
            case .create: return "Create"
            case .profile: return "Profile"
            }
        }

        var color: Color {
            switch self {
            case .palace: return VaporwaveColors.neonPink
            case .sessions: return VaporwaveColors.neonCyan
            case .create: return VaporwaveColors.neonPurple
            case .profile: return VaporwaveColors.lavender
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            VaporwaveGradients.background
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                // Main Content
                tabContent

                // Tab Bar
                customTabBar
            }
        }
        .sheet(isPresented: $showSettings) {
            VaporwaveSettings()
                .environmentObject(healthKitManager)
                .environmentObject(audioEngine)
        }
        .onAppear {
            checkOnboarding()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .palace:
            VaporwavePalace()
                .environmentObject(healthKitManager)
                .environmentObject(audioEngine)
                .environmentObject(microphoneManager)

        case .sessions:
            VaporwaveSessions()
                .environmentObject(recordingEngine)

        case .create:
            CreateView()
                .environmentObject(audioEngine)
                .environmentObject(microphoneManager)

        case .profile:
            ProfileView()
                .environmentObject(healthKitManager)
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, VaporwaveSpacing.md)
        .padding(.top, VaporwaveSpacing.md)
        .padding(.bottom, VaporwaveSpacing.lg)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.95)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
        )
    }

    private func tabButton(for tab: Tab) -> some View {
        Button(action: {
            withAnimation(VaporwaveAnimation.smooth) {
                selectedTab = tab
            }

            // Haptic
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
        }) {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedTab == tab ? tab.color : VaporwaveColors.textTertiary)
                    .neonGlow(color: selectedTab == tab ? tab.color : .clear, radius: 8)

                Text(tab.label)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(selectedTab == tab ? tab.color : VaporwaveColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("\(tab.label) tab")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
        .accessibilityHint("Double tap to switch to \(tab.label.lowercased())")
    }

    // MARK: - Helpers

    private func checkOnboarding() {
        // Show onboarding if first launch
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        if !hasSeenOnboarding {
            showOnboarding = true
        }
    }
}

// MARK: - Create View (Placeholder)

struct CreateView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.xl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(VaporwaveColors.neonPurple.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(VaporwaveColors.neonPurple)
                }
                .neonGlow(color: VaporwaveColors.neonPurple, radius: 20)

                Text("CREATE")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("Start a new bio-reactive session")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textSecondary)

                // Quick Start Buttons
                VStack(spacing: VaporwaveSpacing.md) {
                    quickStartButton(
                        title: "New Focus Session",
                        subtitle: "Deep work with bio-feedback",
                        icon: "brain.head.profile",
                        color: VaporwaveColors.neonCyan
                    )

                    quickStartButton(
                        title: "Record & Create",
                        subtitle: "Music production mode",
                        icon: "mic.circle",
                        color: VaporwaveColors.neonPurple
                    )

                    quickStartButton(
                        title: "Live Performance",
                        subtitle: "OSC output enabled",
                        icon: "dot.radiowaves.left.and.right",
                        color: VaporwaveColors.neonPink
                    )
                }
                .padding(.horizontal, VaporwaveSpacing.lg)

                Spacer()
            }
        }
    }

    private func quickStartButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        Button(action: { /* Start session */ }) {
            HStack(spacing: VaporwaveSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(subtitle)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Double tap to start this session type")
    }
}

// MARK: - Profile View (Placeholder)

struct ProfileView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: VaporwaveSpacing.xl) {
                    // Header
                    VStack(spacing: VaporwaveSpacing.md) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            VaporwaveColors.neonPink,
                                            VaporwaveColors.neonPurple
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)

                            Text("N9")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .neonGlow(color: VaporwaveColors.neonPink, radius: 15)

                        Text("NIA9ARA")
                            .font(VaporwaveTypography.sectionTitle())
                            .foregroundColor(VaporwaveColors.textPrimary)

                        Text("Flüssiges Licht")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.textTertiary)
                            .tracking(4)
                    }
                    .padding(.top, VaporwaveSpacing.xxl)

                    // Stats
                    HStack(spacing: VaporwaveSpacing.lg) {
                        statBox(value: "42", label: "Sessions")
                        statBox(value: "68h", label: "Flow Time")
                        statBox(value: "72", label: "Avg Coherence")
                    }
                    .padding(.horizontal, VaporwaveSpacing.lg)

                    // Achievements
                    VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
                        Text("ACHIEVEMENTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(VaporwaveColors.textTertiary)
                            .tracking(2)
                            .padding(.horizontal, VaporwaveSpacing.lg)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: VaporwaveSpacing.md) {
                                achievementBadge(icon: "flame.fill", title: "7 Day Streak", color: VaporwaveColors.coral)
                                achievementBadge(icon: "star.fill", title: "Flow Master", color: VaporwaveColors.coherenceHigh)
                                achievementBadge(icon: "heart.fill", title: "Heart Sync", color: VaporwaveColors.heartRate)
                                achievementBadge(icon: "waveform", title: "Creator", color: VaporwaveColors.neonPurple)
                            }
                            .padding(.horizontal, VaporwaveSpacing.lg)
                        }
                    }

                    // Connect
                    VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
                        Text("CONNECTIONS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(VaporwaveColors.textTertiary)
                            .tracking(2)

                        connectionRow(
                            icon: "applewatch",
                            title: "Apple Watch",
                            status: healthKitManager.isAuthorized ? "Connected" : "Not Connected",
                            connected: healthKitManager.isAuthorized
                        )

                        connectionRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "OSC Output",
                            status: "Ready",
                            connected: true
                        )

                        connectionRow(
                            icon: "pianokeys",
                            title: "Ableton Link",
                            status: "Searching...",
                            connected: false
                        )
                    }
                    .padding(.horizontal, VaporwaveSpacing.lg)

                    Spacer(minLength: VaporwaveSpacing.xxl)
                }
            }
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(VaporwaveTypography.dataSmall())
                .foregroundColor(VaporwaveColors.neonCyan)

            Text(label)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func achievementBadge(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            .neonGlow(color: color, radius: 8)

            Text(title)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textSecondary)
        }
        .padding(VaporwaveSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement: \(title)")
    }

    private func connectionRow(icon: String, title: String, status: String, connected: Bool) -> some View {
        HStack(spacing: VaporwaveSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(connected ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                .frame(width: 32)

            Text(title)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(connected ? VaporwaveColors.success : VaporwaveColors.warning)
                    .frame(width: 8, height: 8)

                Text(status)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(status)")
        .accessibilityValue(connected ? "Connected" : "Not connected")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VaporwaveApp()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
        .environmentObject(MicrophoneManager())
        .environmentObject(RecordingEngine())
}
#endif
