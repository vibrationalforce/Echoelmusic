import SwiftUI
import Combine

// MARK: - Echoelmusic Unified Experience
// The comprehensive hub that connects ALL features at the highest level.
// Every feature interconnects, UI adapts to user abilities,
// navigation flows naturally based on context.
//
// This is the TOP-LEVEL view that replaces/wraps existing navigation.
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────────┐
// │                   EchoelUnifiedExperience                        │
// │                                                                  │
// │  ┌──────────────┐  ┌──────────────────────────────────────────┐ │
// │  │   Adaptive   │  │          Content Area                     │ │
// │  │  Navigation  │  │  ┌────────────────────────────────────┐  │ │
// │  │              │  │  │  Workspace Content (routed)         │  │ │
// │  │  Context ──► │  │  │                                    │  │ │
// │  │  Sidebar     │  │  │  Home | Audio | Video | Create ... │  │ │
// │  │  Bio Status  │  │  │                                    │  │ │
// │  │  Complexity  │  │  └────────────────────────────────────┘  │ │
// │  │              │  │  ┌────────────────────────────────────┐  │ │
// │  │              │  │  │  Interconnection Status Bar         │  │ │
// │  └──────────────┘  │  └────────────────────────────────────┘  │ │
// │                    └──────────────────────────────────────────┘ │
// │                                                                  │
// │  ┌──────────────────────────────────────────────────────────┐   │
// │  │  Feature Interconnection Layer (always running)           │   │
// │  │  Bio ↔ Audio ↔ Video ↔ Lighting ↔ Quantum ↔ Collab     │   │
// │  └──────────────────────────────────────────────────────────┘   │
// │                                                                  │
// │  ┌──────────────────────────────────────────────────────────┐   │
// │  │  Universal Accessibility Engine (always adapting)         │   │
// │  │  Vision + Motor + Hearing + Cognitive + Vestibular       │   │
// │  └──────────────────────────────────────────────────────────┘   │
// └──────────────────────────────────────────────────────────────────┘

// MARK: - Unified Experience View

public struct EchoelUnifiedExperience: View {

    // MARK: - State

    @StateObject private var accessibility = UniversalAccessibilityEngine.shared
    @StateObject private var navigation = AdaptiveNavigationManager.shared
    @StateObject private var tokens = AdaptiveDesignTokens.shared
    @StateObject private var interconnection = FeatureInterconnectionEngine.shared

    @State private var showOnboarding: Bool = false
    @State private var showAccessibilitySettings: Bool = false
    @State private var showInterconnectionMap: Bool = false
    @State private var showContextSwitcher: Bool = false

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Main Navigation with routed content
            AdaptiveNavigationView { workspace in
                workspaceContent(for: workspace)
            }

            // Onboarding overlay
            if showOnboarding {
                inclusiveOnboarding
                    .transition(.opacity)
            }

            // Accessibility settings sheet
            if showAccessibilitySettings {
                accessibilitySettingsOverlay
            }

            // Visual beat indicator for deaf/HoH users
            if accessibility.visualBeatIndicator {
                beatIndicatorOverlay
            }
        }
        .onAppear {
            accessibility.loadSavedProfile()
            if !accessibility.hasCompletedAssessment {
                showOnboarding = true
            }
        }
        .environment(\.adaptiveTokens, tokens)
    }

    // MARK: - Workspace Content Router

    @ViewBuilder
    private func workspaceContent(for workspace: AdaptiveWorkspace) -> some View {
        switch workspace {
        case .home:
            homeHub
        case .audio:
            audioWorkspace
        case .video:
            videoWorkspace
        case .session:
            sessionWorkspace
        case .creative:
            creativeWorkspace
        case .mixing:
            mixingWorkspace
        case .vj:
            vjWorkspace
        case .wellness:
            wellnessWorkspace
        case .collaboration:
            collaborationWorkspace
        case .quantum:
            quantumWorkspace
        case .ai:
            aiWorkspace
        case .settings:
            settingsWorkspace
        default:
            placeholderWorkspace(workspace)
        }
    }

    // MARK: - Home Hub

    private var homeHub: some View {
        ScrollView {
            VStack(spacing: tokens.spacingLG) {

                // Welcome header
                welcomeHeader

                // Quick Actions (always visible)
                quickActionsGrid

                // Bio Dashboard (visible at simple+)
                if accessibility.shouldShowFeature(.bioMetrics) {
                    bioDashboard
                }

                // Active Connections Status
                if accessibility.shouldShowFeature(.effects) {
                    interconnectionStatus
                }

                // Recent Activity
                recentActivity

                // Quick Navigate to other workspaces
                workspaceQuickAccess
            }
            .padding(tokens.spacingMD)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Home workspace")
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(spacing: tokens.spacingSM) {
            Text(welcomeMessage)
                .font(EchoelTypography.title)
                .foregroundColor(VaporwaveColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(contextDescription)
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(tokens.spacingLG)
        .adaptiveCard()
        .accessibilityElement(children: .combine)
    }

    private var welcomeMessage: String {
        let hr = Int(interconnection.currentHeartRate)
        let coherence = interconnection.currentCoherence

        if coherence > 0.7 {
            return "You're in flow"
        } else if hr > 90 {
            return "High energy"
        } else if hr < 60 {
            return "Deep calm"
        } else {
            return "Welcome to Echoelmusic"
        }
    }

    private var contextDescription: String {
        switch navigation.navigationContext {
        case .creating: return "Your creative tools are ready."
        case .performing: return "Stage is set. Let's go."
        case .meditating: return "Breathe. Feel. Create."
        case .collaborating: return "Create together, worldwide."
        case .exploring: return "Discover what's possible."
        case .learning: return "Every journey starts here."
        }
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        let actions: [(String, String, Color, AdaptiveWorkspace)] = [
            ("Play Audio", "play.circle.fill", VaporwaveColors.neonCyan, .audio),
            ("Start Session", "square.grid.3x3.fill", VaporwaveColors.neonPurple, .session),
            ("Create", "paintbrush.fill", VaporwaveColors.lavender, .creative),
            ("Wellness", "leaf.fill", Color(red: 0.4, green: 0.9, blue: 0.5), .wellness),
        ]

        return VStack(alignment: .leading, spacing: tokens.spacingSM) {
            Text("Quick Start")
                .font(EchoelTypography.headline)
                .foregroundColor(VaporwaveColors.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: tokens.spacingMD), count: max(1, tokens.preferredColumns)),
                spacing: tokens.spacingMD
            ) {
                ForEach(actions, id: \.0) { action in
                    Button(action: { navigation.navigateTo(action.3) }) {
                        HStack(spacing: tokens.spacingSM) {
                            Image(systemName: action.1)
                                .font(.system(size: tokens.iconSize))
                                .foregroundColor(action.2)

                            Text(action.0)
                                .font(EchoelTypography.callout)
                                .foregroundColor(VaporwaveColors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(VaporwaveColors.textTertiary)
                        }
                        .frame(minHeight: tokens.preferredTouchTarget)
                        .adaptiveCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(action.0)
                    .accessibilityHint("Navigate to \(action.3.rawValue)")
                }
            }
        }
    }

    // MARK: - Bio Dashboard

    private var bioDashboard: some View {
        VStack(alignment: .leading, spacing: tokens.spacingSM) {
            HStack {
                Text("Bio Status")
                    .font(EchoelTypography.headline)
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                Text(interconnection.currentBioState.rawValue.capitalized)
                    .font(EchoelTypography.caption)
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VaporwaveColors.glassBg)
                    .cornerRadius(tokens.cornerRadiusSM)
            }

            HStack(spacing: tokens.spacingMD) {
                bioMetricCard(
                    icon: SemanticIcon.heartRate,
                    label: "Heart Rate",
                    value: "\(Int(interconnection.currentHeartRate))",
                    unit: "bpm",
                    color: VaporwaveColors.heartRate
                )

                bioMetricCard(
                    icon: SemanticIcon.coherence,
                    label: "Coherence",
                    value: "\(Int(interconnection.currentCoherence * 100))",
                    unit: "%",
                    color: AdaptiveColor.coherence(interconnection.currentCoherence, for: accessibility.profile)
                )

                bioMetricCard(
                    icon: SemanticIcon.breathing,
                    label: "Breathing",
                    value: String(format: "%.1f", interconnection.currentBreathingPhase),
                    unit: "",
                    color: VaporwaveColors.neonCyan
                )
            }
        }
        .padding(tokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                .fill(VaporwaveColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                .stroke(VaporwaveColors.glassBorder, lineWidth: tokens.borderWidth)
        )
    }

    private func bioMetricCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: tokens.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: tokens.iconSize))
                .foregroundColor(color)

            Text(value)
                .font(EchoelTypography.title2)
                .foregroundColor(VaporwaveColors.textPrimary)

            if !unit.isEmpty {
                Text(unit)
                    .font(EchoelTypography.caption2)
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Text(label)
                .font(EchoelTypography.caption)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    // MARK: - Interconnection Status

    private var interconnectionStatus: some View {
        VStack(alignment: .leading, spacing: tokens.spacingSM) {
            HStack {
                Text("Feature Connections")
                    .font(EchoelTypography.headline)
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                Button(action: { showInterconnectionMap = true }) {
                    Text("Map")
                        .font(EchoelTypography.caption)
                        .foregroundColor(VaporwaveColors.neonCyan)
                }
                .accessibilityLabel("Show interconnection map")
            }

            // Active domains
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: tokens.spacingSM) {
                    ForEach(Array(interconnection.activeDomains).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { domain in
                        HStack(spacing: 4) {
                            Image(systemName: domain.icon)
                                .font(.system(size: 14))
                            Text(domain.rawValue)
                                .font(EchoelTypography.caption2)
                        }
                        .foregroundColor(VaporwaveColors.neonCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VaporwaveColors.neonCyan.opacity(0.15))
                        .cornerRadius(tokens.cornerRadiusSM)
                        .accessibilityLabel("\(domain.rawValue) active")
                    }
                }
            }

            // Health bar
            HStack(spacing: tokens.spacingSM) {
                Text("Health")
                    .font(EchoelTypography.caption)
                    .foregroundColor(VaporwaveColors.textTertiary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VaporwaveColors.glassBg)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VaporwaveColors.neonCyan)
                            .frame(width: geo.size.width * interconnection.interconnectionHealth)
                    }
                }
                .frame(height: 8)

                Text("\(Int(interconnection.interconnectionHealth * 100))%")
                    .font(EchoelTypography.caption)
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Interconnection health: \(Int(interconnection.interconnectionHealth * 100)) percent")
        }
        .adaptiveCard()
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: tokens.spacingSM) {
            Text("Activity")
                .font(EchoelTypography.headline)
                .foregroundColor(VaporwaveColors.textPrimary)

            if interconnection.eventLog.isEmpty {
                Text("No activity yet. Start creating!")
                    .font(EchoelTypography.body)
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .padding(tokens.spacingMD)
            } else {
                ForEach(interconnection.eventLog.suffix(5)) { entry in
                    HStack(spacing: tokens.spacingSM) {
                        Circle()
                            .fill(VaporwaveColors.neonCyan)
                            .frame(width: 6, height: 6)
                        Text(entry.description)
                            .font(EchoelTypography.caption)
                            .foregroundColor(VaporwaveColors.textSecondary)
                        Spacer()
                    }
                }
            }
        }
        .adaptiveCard()
    }

    // MARK: - Workspace Quick Access

    private var workspaceQuickAccess: some View {
        VStack(alignment: .leading, spacing: tokens.spacingSM) {
            Text("Workspaces")
                .font(EchoelTypography.headline)
                .foregroundColor(VaporwaveColors.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: tokens.spacingMD), count: max(1, min(4, tokens.preferredColumns * 2))),
                spacing: tokens.spacingMD
            ) {
                ForEach(navigation.allAvailableWorkspaces.filter { $0 != .home && $0 != .settings }) { workspace in
                    Button(action: { navigation.navigateTo(workspace) }) {
                        VStack(spacing: tokens.spacingSM) {
                            Image(systemName: workspace.icon)
                                .font(.system(size: tokens.iconSize * 1.2))
                                .foregroundColor(workspace.color)

                            Text(workspace.rawValue)
                                .font(EchoelTypography.caption)
                                .foregroundColor(VaporwaveColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: tokens.comfortTouchTarget)
                        .adaptiveCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(workspace.rawValue)
                    .accessibilityHint("Navigate to \(workspace.rawValue)")
                }
            }
        }
    }

    // MARK: - Workspace Placeholders

    private var audioWorkspace: some View {
        workspaceContainer(title: "Audio Engine", icon: "waveform", color: VaporwaveColors.neonCyan) {
            VStack(spacing: tokens.spacingMD) {
                Text("Audio synthesis, effects, spatial positioning")
                    .font(EchoelTypography.body)
                    .foregroundColor(VaporwaveColors.textSecondary)

                // Audio level meter
                HStack(spacing: 2) {
                    ForEach(0..<24, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < 16 ? VaporwaveColors.neonCyan : i < 20 ? VaporwaveColors.warning : VaporwaveColors.heartRate)
                            .frame(width: 8, height: CGFloat(i + 4) * 2)
                    }
                }
                .frame(height: 60)
                .accessibilityLabel("Audio level meter")
            }
        }
    }

    private var videoWorkspace: some View {
        workspaceContainer(title: "Video Editor", icon: "film", color: VaporwaveColors.coral) {
            Text("Timeline, effects, beat-synced editing")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var sessionWorkspace: some View {
        workspaceContainer(title: "Session View", icon: "square.grid.3x3", color: VaporwaveColors.neonPurple) {
            Text("Clip launcher, patterns, scene triggering")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var creativeWorkspace: some View {
        workspaceContainer(title: "Creative Studio", icon: "paintbrush", color: VaporwaveColors.lavender) {
            Text("AI art generation, music composition, fractals")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var mixingWorkspace: some View {
        workspaceContainer(title: "Mixing Console", icon: "slider.horizontal.3", color: VaporwaveColors.neonCyan) {
            Text("Channel strips, EQ, dynamics, sends, bus routing")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var vjWorkspace: some View {
        workspaceContainer(title: "VJ / Laser", icon: "lightbulb.led.fill", color: Color(red: 0, green: 1, blue: 0.5)) {
            Text("Visual performance, DMX, Art-Net, laser control")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var wellnessWorkspace: some View {
        workspaceContainer(title: "Wellness", icon: "leaf.fill", color: Color(red: 0.4, green: 0.9, blue: 0.5)) {
            VStack(spacing: tokens.spacingMD) {
                Text("Meditation, breathing, bio-reactive relaxation")
                    .font(EchoelTypography.body)
                    .foregroundColor(VaporwaveColors.textSecondary)

                // Breathing guide visualization
                breathingGuide

                Text("For general wellness only. Not medical advice.")
                    .font(EchoelTypography.caption2)
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var collaborationWorkspace: some View {
        workspaceContainer(title: "Together", icon: "person.3.fill", color: Color(red: 0.4, green: 0.8, blue: 1.0)) {
            Text("Worldwide sessions, group coherence, real-time sync")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var quantumWorkspace: some View {
        workspaceContainer(title: "Quantum", icon: "atom", color: Color(red: 0.6, green: 0.3, blue: 1.0)) {
            Text("Quantum-inspired audio processing and visualization")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var aiWorkspace: some View {
        workspaceContainer(title: "AI Tools", icon: "brain.head.profile", color: Color(red: 0.8, green: 0.2, blue: 1.0)) {
            Text("AI-powered composition, sound design, mastering")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    private var settingsWorkspace: some View {
        ScrollView {
            VStack(spacing: tokens.spacingLG) {
                // Accessibility Settings
                settingsSection(title: "Accessibility", icon: "accessibility") {
                    VStack(spacing: tokens.spacingSM) {
                        // Profile presets
                        ForEach(UniversalAccessibilityEngine.ProfilePreset.allCases, id: \.rawValue) { preset in
                            Button(action: { accessibility.applyPresetProfile(preset) }) {
                                HStack(spacing: tokens.spacingSM) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: tokens.iconSize))
                                        .frame(width: 32)
                                    VStack(alignment: .leading) {
                                        Text(preset.rawValue)
                                            .font(EchoelTypography.callout)
                                            .foregroundColor(VaporwaveColors.textPrimary)
                                    }
                                    Spacer()
                                }
                                .frame(minHeight: tokens.preferredTouchTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(preset.rawValue)
                        }
                    }
                }

                // Complexity Level
                settingsSection(title: "Interface Level", icon: "slider.horizontal.below.rectangle") {
                    VStack(spacing: tokens.spacingSM) {
                        ForEach(UniversalAccessibilityEngine.ComplexityLevel.allCases, id: \.rawValue) { level in
                            Button(action: { accessibility.complexityLevel = level }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(level.label)
                                            .font(EchoelTypography.callout)
                                            .foregroundColor(VaporwaveColors.textPrimary)
                                        Text(level.description)
                                            .font(EchoelTypography.caption)
                                            .foregroundColor(VaporwaveColors.textTertiary)
                                    }
                                    Spacer()
                                    if accessibility.complexityLevel == level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(VaporwaveColors.neonCyan)
                                    }
                                }
                                .frame(minHeight: tokens.preferredTouchTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(level.label): \(level.description)")
                            .accessibilityAddTraits(accessibility.complexityLevel == level ? .isSelected : [])
                        }
                    }
                }

                // Interconnection Presets
                settingsSection(title: "Feature Connections", icon: "link") {
                    VStack(spacing: tokens.spacingSM) {
                        ForEach(FeatureInterconnectionEngine.InterconnectionPreset.allCases, id: \.rawValue) { preset in
                            Button(action: { interconnection.applyPreset(preset) }) {
                                HStack {
                                    Text(preset.rawValue)
                                        .font(EchoelTypography.callout)
                                        .foregroundColor(VaporwaveColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(VaporwaveColors.textTertiary)
                                }
                                .frame(minHeight: tokens.preferredTouchTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Apply \(preset.rawValue) preset")
                        }
                    }
                }
            }
            .padding(tokens.spacingMD)
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func workspaceContainer<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: tokens.spacingLG) {
                // Header
                HStack(spacing: tokens.spacingSM) {
                    Image(systemName: icon)
                        .font(.system(size: tokens.iconSize * 1.5))
                        .foregroundColor(color)
                    Text(title)
                        .font(EchoelTypography.title)
                        .foregroundColor(VaporwaveColors.textPrimary)
                    Spacer()
                }
                .padding(tokens.spacingMD)

                content()

                // Bio-reactive connection indicator
                if accessibility.shouldShowFeature(.bioMetrics) {
                    bioConnectionIndicator(for: title)
                }
            }
            .padding(tokens.spacingMD)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) workspace")
    }

    private func bioConnectionIndicator(for workspace: String) -> some View {
        HStack(spacing: tokens.spacingSM) {
            Image(systemName: "heart.fill")
                .foregroundColor(VaporwaveColors.heartRate.opacity(0.6))
            Text("Bio-reactive: your body shapes the sound")
                .font(EchoelTypography.caption)
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .padding(tokens.spacingSM)
        .background(VaporwaveColors.glassBg)
        .cornerRadius(tokens.cornerRadiusSM)
        .accessibilityLabel("Bio-reactive features active: your biometric data influences this workspace")
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingSM) {
            HStack(spacing: tokens.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: tokens.iconSize))
                    .foregroundColor(VaporwaveColors.neonCyan)
                Text(title)
                    .font(EchoelTypography.headline)
                    .foregroundColor(VaporwaveColors.textPrimary)
            }

            content()
        }
        .adaptiveCard()
    }

    // MARK: - Breathing Guide

    private var breathingGuide: some View {
        VStack(spacing: tokens.spacingSM) {
            Circle()
                .stroke(Color(red: 0.4, green: 0.9, blue: 0.5).opacity(0.3), lineWidth: 3)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.4, green: 0.9, blue: 0.5).opacity(0.15))
                )
                .accessibilityLabel("Breathing guide circle")

            Text("Breathe with the circle")
                .font(EchoelTypography.caption)
                .foregroundColor(VaporwaveColors.textTertiary)
        }
    }

    // MARK: - Placeholder

    private func placeholderWorkspace(_ workspace: AdaptiveWorkspace) -> some View {
        VStack(spacing: tokens.spacingMD) {
            Image(systemName: workspace.icon)
                .font(.system(size: 48))
                .foregroundColor(workspace.color)

            Text(workspace.rawValue)
                .font(EchoelTypography.title)
                .foregroundColor(VaporwaveColors.textPrimary)

            Text("Coming soon")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("\(workspace.rawValue) workspace. Coming soon.")
    }

    // MARK: - Overlays

    private var inclusiveOnboarding: some View {
        OnboardingAssessmentView(
            onComplete: { profile in
                accessibility.profile = profile
                accessibility.hasCompletedAssessment = true
                showOnboarding = false
            },
            onSkip: {
                showOnboarding = false
            }
        )
    }

    private var accessibilitySettingsOverlay: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .onTapGesture {
                showAccessibilitySettings = false
            }
    }

    private var beatIndicatorOverlay: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(VaporwaveColors.neonCyan, lineWidth: 4)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Onboarding Assessment View

struct OnboardingAssessmentView: View {
    let onComplete: (AbilityProfile) -> Void
    let onSkip: () -> Void

    @State private var currentStep = 0
    @State private var profile = AbilityProfile.standard
    @ObservedObject private var tokens = AdaptiveDesignTokens.shared

    private let questions = AbilityAssessment.questions

    var body: some View {
        ZStack {
            // Background
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: tokens.spacingLG) {
                Spacer()

                // Logo
                VStack(spacing: tokens.spacingSM) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(VaporwaveColors.neonPink)

                    Text("Echoelmusic")
                        .font(EchoelTypography.largeTitle)
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text("Let's set up your experience")
                        .font(EchoelTypography.body)
                        .foregroundColor(VaporwaveColors.textSecondary)
                }

                Spacer()

                if currentStep < questions.count {
                    // Question card
                    questionCard(questions[currentStep])
                } else {
                    // Complete
                    completeCard
                }

                // Progress + Skip
                HStack {
                    Button("Skip") {
                        onSkip()
                    }
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .accessibilityLabel("Skip setup")

                    Spacer()

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<questions.count, id: \.self) { i in
                            Circle()
                                .fill(i <= currentStep ? VaporwaveColors.neonCyan : VaporwaveColors.glassBorder)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityLabel("Step \(currentStep + 1) of \(questions.count)")
                }
                .padding(.horizontal, tokens.spacingLG)

                Spacer()
            }
            .padding(tokens.spacingLG)
        }
    }

    @ViewBuilder
    private func questionCard(_ question: AbilityAssessment.AssessmentQuestion) -> some View {
        VStack(spacing: tokens.spacingLG) {
            Image(systemName: question.icon)
                .font(.system(size: 40))
                .foregroundColor(VaporwaveColors.neonCyan)

            Text(question.title)
                .font(EchoelTypography.title2)
                .foregroundColor(VaporwaveColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(question.description)
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: tokens.spacingSM) {
                ForEach(question.options) { option in
                    Button(action: {
                        option.profileAdjustment(&profile)
                        currentStep += 1
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(EchoelTypography.headline)
                                .foregroundColor(VaporwaveColors.textPrimary)
                            Text(option.description)
                                .font(EchoelTypography.caption)
                                .foregroundColor(VaporwaveColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: tokens.preferredTouchTarget)
                        .padding(tokens.spacingSM)
                        .background(VaporwaveColors.glassBg)
                        .cornerRadius(tokens.cornerRadiusMD)
                        .overlay(
                            RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                                .stroke(VaporwaveColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.label): \(option.description)")
                }
            }
        }
        .padding(tokens.spacingLG)
        .background(VaporwaveColors.glassBg)
        .cornerRadius(tokens.cornerRadiusLG)
        .accessibilityElement(children: .contain)
    }

    private var completeCard: some View {
        VStack(spacing: tokens.spacingLG) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(VaporwaveColors.neonCyan)

            Text("You're all set!")
                .font(EchoelTypography.title)
                .foregroundColor(VaporwaveColors.textPrimary)

            Text("Your experience has been personalized. You can change these settings anytime.")
                .font(EchoelTypography.body)
                .foregroundColor(VaporwaveColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: { onComplete(profile) }) {
                Text("Start Creating")
                    .font(EchoelTypography.headline)
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .frame(maxWidth: .infinity)
                    .frame(height: tokens.comfortTouchTarget)
                    .background(VaporwaveColors.neonCyan)
                    .cornerRadius(tokens.cornerRadiusMD)
            }
            .accessibilityLabel("Start creating")
        }
        .padding(tokens.spacingLG)
        .background(VaporwaveColors.glassBg)
        .cornerRadius(tokens.cornerRadiusLG)
    }
}

// MARK: - Environment Key for Adaptive Tokens

private struct AdaptiveTokensKey: EnvironmentKey {
    static let defaultValue = AdaptiveDesignTokens.shared
}

extension EnvironmentValues {
    var adaptiveTokens: AdaptiveDesignTokens {
        get { self[AdaptiveTokensKey.self] }
        set { self[AdaptiveTokensKey.self] = newValue }
    }
}
