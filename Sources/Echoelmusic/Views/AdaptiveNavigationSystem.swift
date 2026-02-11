import SwiftUI
import Combine

// MARK: - Adaptive Navigation System
// Context-aware, inclusive navigation that adapts to:
// - User abilities (motor, vision, cognitive)
// - Device type (iPhone, iPad, Mac, visionOS, tvOS, Watch)
// - Current activity (creating, performing, meditating, collaborating)
// - Screen size and orientation
//
// Navigation Strategies:
// - Desktop: Sidebar + tabs + keyboard shortcuts
// - Mobile: Bottom tabs + swipe gestures + haptic feedback
// - Voice: Voice commands with confirmation
// - Switch: Scanning pattern with large targets
// - Screen Reader: Logical reading order with landmarks

// MARK: - Navigation Context

/// What the user is currently doing determines available navigation
public enum NavigationContext: String, CaseIterable {
    case creating = "Creating"
    case performing = "Performing"
    case meditating = "Meditating"
    case collaborating = "Collaborating"
    case exploring = "Exploring"
    case learning = "Learning"

    public var icon: String {
        switch self {
        case .creating: return "wand.and.stars"
        case .performing: return "music.mic"
        case .meditating: return "leaf"
        case .collaborating: return "person.3"
        case .exploring: return "safari"
        case .learning: return "book"
        }
    }

    public var availableWorkspaces: [AdaptiveWorkspace] {
        switch self {
        case .creating:
            return [.home, .audio, .video, .creative, .mixing, .session]
        case .performing:
            return [.home, .audio, .session, .vj, .streaming, .hardware]
        case .meditating:
            return [.home, .wellness, .audio]
        case .collaborating:
            return [.home, .collaboration, .audio, .streaming]
        case .exploring:
            return AdaptiveWorkspace.allCases
        case .learning:
            return [.home, .audio, .creative, .wellness]
        }
    }
}

// MARK: - Adaptive Workspace

/// Workspaces with adaptive metadata
public enum AdaptiveWorkspace: String, CaseIterable, Identifiable {
    case home = "Home"
    case audio = "Audio"
    case video = "Video"
    case session = "Session"
    case creative = "Create"
    case mixing = "Mix"
    case vj = "VJ"
    case nodes = "Nodes"
    case midi = "MIDI"
    case hardware = "Hardware"
    case streaming = "Stream"
    case collaboration = "Together"
    case wellness = "Wellness"
    case quantum = "Quantum"
    case ai = "AI"
    case settings = "Settings"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .home: return "waveform.circle"
        case .audio: return "waveform"
        case .video: return "film"
        case .session: return "square.grid.3x3"
        case .creative: return "paintbrush"
        case .mixing: return "slider.horizontal.3"
        case .vj: return "lightbulb.led.fill"
        case .nodes: return "point.3.connected.trianglepath.dotted"
        case .midi: return "pianokeys"
        case .hardware: return "cpu"
        case .streaming: return "dot.radiowaves.left.and.right"
        case .collaboration: return "person.3.fill"
        case .wellness: return "leaf.fill"
        case .quantum: return "atom"
        case .ai: return "brain.head.profile"
        case .settings: return "gearshape"
        }
    }

    public var color: Color {
        switch self {
        case .home: return VaporwaveColors.neonPink
        case .audio: return VaporwaveColors.neonCyan
        case .video: return VaporwaveColors.coral
        case .session: return VaporwaveColors.neonPurple
        case .creative: return VaporwaveColors.lavender
        case .mixing: return VaporwaveColors.neonCyan
        case .vj: return Color(red: 0.0, green: 1.0, blue: 0.5)
        case .nodes: return VaporwaveColors.lavender
        case .midi: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .hardware: return VaporwaveColors.coral
        case .streaming: return VaporwaveColors.neonPink
        case .collaboration: return Color(red: 0.4, green: 0.8, blue: 1.0)
        case .wellness: return Color(red: 0.4, green: 0.9, blue: 0.5)
        case .quantum: return Color(red: 0.6, green: 0.3, blue: 1.0)
        case .ai: return Color(red: 0.8, green: 0.2, blue: 1.0)
        case .settings: return VaporwaveColors.textSecondary
        }
    }

    /// Minimum complexity level to see this workspace
    public var minimumComplexity: UniversalAccessibilityEngine.ComplexityLevel {
        switch self {
        case .home, .wellness: return .minimal
        case .audio, .collaboration: return .simple
        case .video, .creative, .session, .quantum: return .standard
        case .mixing, .vj, .streaming, .hardware, .ai: return .full
        case .nodes, .midi, .settings: return .full
        }
    }

    /// Short voice command name
    public var voiceCommand: String {
        switch self {
        case .home: return "home"
        case .audio: return "audio"
        case .video: return "video"
        case .session: return "session"
        case .creative: return "create"
        case .mixing: return "mix"
        case .vj: return "VJ"
        case .nodes: return "nodes"
        case .midi: return "MIDI"
        case .hardware: return "hardware"
        case .streaming: return "stream"
        case .collaboration: return "together"
        case .wellness: return "wellness"
        case .quantum: return "quantum"
        case .ai: return "AI"
        case .settings: return "settings"
        }
    }

    /// Keyboard shortcut
    public var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .home: return "1"
        case .audio: return "2"
        case .session: return "3"
        case .video: return "4"
        case .creative: return "5"
        case .mixing: return "6"
        case .vj: return "7"
        case .collaboration: return "8"
        case .wellness: return "9"
        case .settings: return ","
        default: return nil
        }
    }
}

// MARK: - Adaptive Navigation Manager

@MainActor
public final class AdaptiveNavigationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AdaptiveNavigationManager()

    // MARK: - Dependencies

    @Published private var accessibility = UniversalAccessibilityEngine.shared
    @Published private var tokens = AdaptiveDesignTokens.shared

    // MARK: - State

    @Published public var currentWorkspace: AdaptiveWorkspace = .home
    @Published public var navigationContext: NavigationContext = .exploring
    @Published public var navigationHistory: [AdaptiveWorkspace] = [.home]
    @Published public var showContextSwitcher: Bool = false
    @Published public var breadcrumbs: [String] = ["Home"]

    // MARK: - Computed

    /// Workspaces visible based on context + complexity level
    public var visibleWorkspaces: [AdaptiveWorkspace] {
        let contextWorkspaces = navigationContext.availableWorkspaces
        let complexityLevel = accessibility.complexityLevel

        return contextWorkspaces.filter { workspace in
            workspace.minimumComplexity <= complexityLevel
        }
    }

    /// All workspaces at current complexity level (for explore mode)
    public var allAvailableWorkspaces: [AdaptiveWorkspace] {
        AdaptiveWorkspace.allCases.filter { workspace in
            workspace.minimumComplexity <= accessibility.complexityLevel
        }
    }

    // MARK: - Navigation

    /// Navigate to a workspace with announcements and feedback
    public func navigateTo(_ workspace: AdaptiveWorkspace) {
        let previous = currentWorkspace
        currentWorkspace = workspace

        // Update history
        navigationHistory.append(workspace)
        if navigationHistory.count > 20 {
            navigationHistory.removeFirst()
        }

        // Update breadcrumbs
        if workspace == .home {
            breadcrumbs = ["Home"]
        } else {
            breadcrumbs = ["Home", workspace.rawValue]
        }

        // Announce for screen readers
        accessibility.announce("\(workspace.rawValue) workspace", priority: .screenChanged)

        // Haptic feedback
        accessibility.hapticFeedback(.selection)

        // Emit interconnection event
        FeatureInterconnectionEngine.shared.emit(.workspaceChanged(workspace.rawValue))

        _ = previous
    }

    /// Go back in navigation history
    public func goBack() {
        guard navigationHistory.count > 1 else { return }
        navigationHistory.removeLast()
        if let previous = navigationHistory.last {
            currentWorkspace = previous
            accessibility.announce("Back to \(previous.rawValue)", priority: .screenChanged)
        }
    }

    /// Switch navigation context
    public func switchContext(_ context: NavigationContext) {
        navigationContext = context
        accessibility.announce("Mode: \(context.rawValue)")

        // Navigate to home if current workspace isn't in new context
        if !context.availableWorkspaces.contains(currentWorkspace) {
            navigateTo(.home)
        }
    }

    /// Handle voice command navigation
    public func handleVoiceCommand(_ command: String) {
        let lowered = command.lowercased()

        // Check workspace names
        if let workspace = AdaptiveWorkspace.allCases.first(where: {
            lowered.contains($0.voiceCommand.lowercased())
        }) {
            navigateTo(workspace)
            return
        }

        // Check context names
        if let context = NavigationContext.allCases.first(where: {
            lowered.contains($0.rawValue.lowercased())
        }) {
            switchContext(context)
            return
        }

        // Back command
        if lowered.contains("back") || lowered.contains("previous") {
            goBack()
        }
    }
}

// MARK: - Adaptive Navigation View

/// The main navigation chrome that adapts to everything
public struct AdaptiveNavigationView<Content: View>: View {
    @ObservedObject var nav = AdaptiveNavigationManager.shared
    @ObservedObject var accessibility = UniversalAccessibilityEngine.shared
    @ObservedObject var tokens = AdaptiveDesignTokens.shared
    @ObservedObject var interconnection = FeatureInterconnectionEngine.shared

    let content: (AdaptiveWorkspace) -> Content

    public init(@ViewBuilder content: @escaping (AdaptiveWorkspace) -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                AdaptiveColor.background(for: accessibility.profile)
                    .ignoresSafeArea()

                // Layout based on platform and size
                #if os(iOS)
                if geometry.size.width > 768 {
                    desktopNavigationLayout(geometry: geometry)
                } else {
                    mobileNavigationLayout(geometry: geometry)
                }
                #elseif os(macOS)
                desktopNavigationLayout(geometry: geometry)
                #elseif os(tvOS)
                tvOSNavigationLayout(geometry: geometry)
                #else
                desktopNavigationLayout(geometry: geometry)
                #endif
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Echoelmusic")
    }

    // MARK: - Desktop Layout

    @ViewBuilder
    private func desktopNavigationLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Sidebar
            adaptiveSidebar
                .frame(width: sidebarWidth)

            // Divider
            Rectangle()
                .fill(VaporwaveColors.glassBorder)
                .frame(width: 1)

            // Main Content
            VStack(spacing: 0) {
                // Top bar with bio status
                adaptiveTopBar

                // Content area
                content(nav.currentWorkspace)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Transport bar
                adaptiveTransportBar
            }
        }
    }

    // MARK: - Mobile Layout

    @ViewBuilder
    private func mobileNavigationLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Mobile status bar
            mobileStatusBar

            // Content
            content(nav.currentWorkspace)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom tabs
            adaptiveTabBar
        }
    }

    // MARK: - tvOS Layout

    @ViewBuilder
    private func tvOSNavigationLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top navigation strip
            ScrollView(.horizontal) {
                HStack(spacing: tokens.spacingLG) {
                    ForEach(nav.visibleWorkspaces) { workspace in
                        Button(action: { nav.navigateTo(workspace) }) {
                            VStack(spacing: tokens.spacingSM) {
                                Image(systemName: workspace.icon)
                                    .font(.title)
                                Text(workspace.rawValue)
                                    .font(EchoelTypography.caption)
                            }
                            .foregroundColor(workspace == nav.currentWorkspace ? workspace.color : VaporwaveColors.textSecondary)
                            .padding(tokens.spacingMD)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(workspace.rawValue)
                    }
                }
                .padding(.horizontal, tokens.spacingXL)
            }
            .frame(height: 100)

            content(nav.currentWorkspace)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Sidebar

    private var adaptiveSidebar: some View {
        VStack(spacing: 0) {
            // Logo area
            HStack(spacing: tokens.spacingSM) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(VaporwaveColors.neonPink)
                Text("Echoelmusic")
                    .font(EchoelTypography.headline)
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
            .padding(tokens.spacingMD)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Echoelmusic")

            Divider().background(VaporwaveColors.glassBorder)

            // Context switcher
            contextSwitcherButton
                .padding(.horizontal, tokens.spacingSM)
                .padding(.vertical, tokens.spacingXS)

            Divider().background(VaporwaveColors.glassBorder)

            // Workspace list
            ScrollView {
                VStack(spacing: tokens.spacingXS) {
                    ForEach(nav.visibleWorkspaces) { workspace in
                        sidebarButton(for: workspace)
                    }
                }
                .padding(tokens.spacingSM)
            }

            Spacer()

            // Bio metrics summary
            bioMetricsSummary
                .padding(tokens.spacingSM)

            // Complexity level indicator
            complexityIndicator
                .padding(tokens.spacingSM)
        }
        .background(VaporwaveColors.glassBg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation sidebar")
    }

    private func sidebarButton(for workspace: AdaptiveWorkspace) -> some View {
        Button(action: { nav.navigateTo(workspace) }) {
            HStack(spacing: tokens.spacingSM) {
                Image(systemName: workspace.icon)
                    .font(.system(size: tokens.iconSize))
                    .foregroundColor(workspace == nav.currentWorkspace ? workspace.color : VaporwaveColors.textSecondary)
                    .frame(width: tokens.iconSize + 4)

                Text(workspace.rawValue)
                    .font(EchoelTypography.callout)
                    .foregroundColor(workspace == nav.currentWorkspace ? VaporwaveColors.textPrimary : VaporwaveColors.textSecondary)

                Spacer()

                if let shortcut = workspace.keyboardShortcut {
                    Text("\(shortcut)")
                        .font(EchoelTypography.caption2)
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VaporwaveColors.glassBg)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, tokens.spacingSM)
            .frame(minHeight: tokens.minTouchTarget)
            .background(
                workspace == nav.currentWorkspace
                    ? workspace.color.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(tokens.cornerRadiusSM)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(workspace.rawValue)
        .accessibilityHint("Navigate to \(workspace.rawValue) workspace")
        .accessibilityAddTraits(workspace == nav.currentWorkspace ? .isSelected : [])
    }

    // MARK: - Context Switcher

    private var contextSwitcherButton: some View {
        Menu {
            ForEach(NavigationContext.allCases, id: \.rawValue) { context in
                Button(action: { nav.switchContext(context) }) {
                    Label(context.rawValue, systemImage: context.icon)
                }
            }
        } label: {
            HStack(spacing: tokens.spacingSM) {
                Image(systemName: nav.navigationContext.icon)
                    .font(.system(size: tokens.iconSize * 0.8))
                Text(nav.navigationContext.rawValue)
                    .font(EchoelTypography.subheadline)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .foregroundColor(VaporwaveColors.textSecondary)
            .padding(tokens.spacingSM)
            .background(VaporwaveColors.glassBg)
            .cornerRadius(tokens.cornerRadiusSM)
        }
        .accessibilityLabel("Mode: \(nav.navigationContext.rawValue)")
        .accessibilityHint("Change navigation mode")
    }

    // MARK: - Top Bar

    private var adaptiveTopBar: some View {
        HStack(spacing: tokens.spacingMD) {
            // Breadcrumbs
            HStack(spacing: tokens.spacingXS) {
                ForEach(Array(nav.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                    Text(crumb)
                        .font(EchoelTypography.subheadline)
                        .foregroundColor(index == nav.breadcrumbs.count - 1 ? VaporwaveColors.textPrimary : VaporwaveColors.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You are in: \(nav.breadcrumbs.joined(separator: ", "))")

            Spacer()

            // Bio status compact
            if accessibility.shouldShowFeature(.bioMetrics) {
                compactBioStatus
            }

            // Interconnection health
            interconnectionHealthBadge
        }
        .padding(.horizontal, tokens.spacingMD)
        .padding(.vertical, tokens.spacingSM)
        .background(VaporwaveColors.glassBg)
    }

    // MARK: - Transport Bar

    private var adaptiveTransportBar: some View {
        HStack(spacing: tokens.spacingMD) {
            // Play/Pause
            Button(action: {
                accessibility.hapticFeedback(.medium)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: tokens.iconSize))
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
            .adaptiveTouchTarget(.standard)
            .accessibilityLabel("Play")

            // BPM
            Text("\(Int(interconnection.currentBPM)) BPM")
                .font(EchoelTypography.monospaced)
                .foregroundColor(VaporwaveColors.neonCyan)
                .accessibilityLabel("\(Int(interconnection.currentBPM)) beats per minute")

            Spacer()

            // Connection status
            HStack(spacing: tokens.spacingXS) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(EchoelTypography.caption)
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("System connected")
        }
        .padding(.horizontal, tokens.spacingMD)
        .padding(.vertical, tokens.spacingSM)
        .background(VaporwaveColors.glassBg)
    }

    // MARK: - Mobile Elements

    private var mobileStatusBar: some View {
        HStack(spacing: tokens.spacingSM) {
            Text(nav.currentWorkspace.rawValue)
                .font(EchoelTypography.headline)
                .foregroundColor(VaporwaveColors.textPrimary)

            Spacer()

            if accessibility.shouldShowFeature(.bioMetrics) {
                compactBioStatus
            }
        }
        .padding(.horizontal, tokens.spacingMD)
        .padding(.vertical, tokens.spacingSM)
        .background(VaporwaveColors.glassBg)
    }

    private var adaptiveTabBar: some View {
        HStack(spacing: 0) {
            ForEach(nav.visibleWorkspaces.prefix(5)) { workspace in
                Button(action: { nav.navigateTo(workspace) }) {
                    VStack(spacing: 2) {
                        Image(systemName: workspace.icon)
                            .font(.system(size: tokens.iconSize * 0.9))
                        if tokens.showLabelsAlways || workspace == nav.currentWorkspace {
                            Text(workspace.rawValue)
                                .font(EchoelTypography.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(workspace == nav.currentWorkspace ? workspace.color : VaporwaveColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: tokens.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workspace.rawValue)
                .accessibilityAddTraits(workspace == nav.currentWorkspace ? .isSelected : [])
            }
        }
        .padding(.horizontal, tokens.spacingXS)
        .padding(.bottom, tokens.spacingXS)
        .background(VaporwaveColors.glassBg)
    }

    // MARK: - Bio Status Components

    private var compactBioStatus: some View {
        HStack(spacing: tokens.spacingSM) {
            // Heart rate
            HStack(spacing: 4) {
                Image(systemName: SemanticIcon.heartRate)
                    .foregroundColor(VaporwaveColors.heartRate)
                Text("\(Int(interconnection.currentHeartRate))")
                    .font(EchoelTypography.caption)
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate: \(Int(interconnection.currentHeartRate)) beats per minute")

            // Coherence
            HStack(spacing: 4) {
                Image(systemName: SemanticIcon.coherence)
                    .foregroundColor(AdaptiveColor.coherence(interconnection.currentCoherence, for: accessibility.profile))
                Text("\(Int(interconnection.currentCoherence * 100))%")
                    .font(EchoelTypography.caption)
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coherence: \(Int(interconnection.currentCoherence * 100)) percent")
        }
    }

    private var bioMetricsSummary: some View {
        VStack(spacing: tokens.spacingSM) {
            HStack {
                Image(systemName: SemanticIcon.heartRate)
                    .foregroundColor(VaporwaveColors.heartRate)
                Text("\(Int(interconnection.currentHeartRate)) bpm")
                    .font(EchoelTypography.caption)
                Spacer()
            }
            HStack {
                Image(systemName: SemanticIcon.coherence)
                    .foregroundColor(AdaptiveColor.coherence(interconnection.currentCoherence, for: accessibility.profile))
                Text("\(Int(interconnection.currentCoherence * 100))% coherence")
                    .font(EchoelTypography.caption)
                Spacer()
            }
        }
        .foregroundColor(VaporwaveColors.textSecondary)
        .padding(tokens.spacingSM)
        .background(VaporwaveColors.glassBg)
        .cornerRadius(tokens.cornerRadiusSM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate \(Int(interconnection.currentHeartRate)), coherence \(Int(interconnection.currentCoherence * 100)) percent")
    }

    private var interconnectionHealthBadge: some View {
        let health = interconnection.interconnectionHealth
        let icon = health > 0.8 ? "link.circle.fill" : health > 0.5 ? "link.circle" : "link.badge.plus"

        return Image(systemName: icon)
            .foregroundColor(health > 0.8 ? VaporwaveColors.success : VaporwaveColors.warning)
            .accessibilityLabel("Feature interconnection: \(Int(health * 100)) percent")
    }

    private var complexityIndicator: some View {
        HStack(spacing: tokens.spacingXS) {
            Text(accessibility.complexityLevel.label)
                .font(EchoelTypography.caption2)
                .foregroundColor(VaporwaveColors.textTertiary)
            Spacer()
            ForEach(0..<5) { i in
                Circle()
                    .fill(i < accessibility.complexityLevel.rawValue + 1 ? VaporwaveColors.neonCyan : VaporwaveColors.glassBorder)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Interface level: \(accessibility.complexityLevel.label)")
    }

    // MARK: - Helpers

    private var sidebarWidth: CGFloat {
        tokens.showLabelsAlways ? 240 : 220
    }
}
