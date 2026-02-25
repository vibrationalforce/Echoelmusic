import SwiftUI

// MARK: - Main Navigation Hub
// Unified workspace navigation for Echoelmusic - Multi-Billion Dollar Production Interface
// Connects all professional views: DAW, Video, VJ/Laser, Node Editor, AI, Sessions

struct MainNavigationHub: View {

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var recordingEngine: RecordingEngine

    // MARK: - State

    @State private var currentWorkspace: Workspace = .palace
    @State private var sidebarExpanded = true
    @State private var showQuickActions = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var coherence: Double = 0.75
    @State private var heartRate: Int = 72
    @State private var isPlaying = false
    @State private var bpm: Double = 120.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Workspaces

    enum Workspace: String, CaseIterable, Identifiable {
        case palace = "Palace"
        case daw = "DAW"
        case session = "Session"
        case video = "Video"
        case vj = "VJ/Laser"
        case nodes = "Nodes"
        case midi = "MIDI"
        case mixing = "Mixing"
        case ai = "AI Tools"
        case hardware = "Hardware"
        case streaming = "Stream"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .palace: return "waveform.circle"
            case .daw: return "pianokeys"
            case .session: return "square.grid.3x3"
            case .video: return "film"
            case .vj: return "lightbulb.led.fill"
            case .nodes: return "point.3.connected.trianglepath.dotted"
            case .midi: return "cable.connector"
            case .mixing: return "slider.horizontal.3"
            case .ai: return "brain.head.profile"
            case .hardware: return "cpu"
            case .streaming: return "dot.radiowaves.left.and.right"
            case .settings: return "gearshape"
            }
        }

        /// Filled variant for selected state in tab bars.
        /// Some SF Symbols don't have a .fill variant or already end in .fill.
        var filledIcon: String {
            switch self {
            case .palace: return "waveform.circle.fill"
            case .daw: return "pianokeys.inverse"
            case .session: return "square.grid.3x3.fill"
            case .video: return "film.fill"
            case .vj: return "lightbulb.led.fill"
            case .nodes: return "point.3.connected.trianglepath.dotted"
            case .midi: return "cable.connector.horizontal"
            case .mixing: return "slider.horizontal.3"
            case .ai: return "brain.head.profile.fill"
            case .hardware: return "cpu.fill"
            case .streaming: return "dot.radiowaves.left.and.right"
            case .settings: return "gearshape.fill"
            }
        }

        var color: Color {
            switch self {
            case .palace: return VaporwaveColors.neonPink
            case .daw: return VaporwaveColors.neonCyan
            case .session: return VaporwaveColors.neonPurple
            case .video: return VaporwaveColors.coral
            case .vj: return VaporwaveColors.coherenceHigh
            case .nodes: return VaporwaveColors.lavender
            case .midi: return VaporwaveColors.coherenceMedium
            case .mixing: return VaporwaveColors.neonCyan
            case .ai: return VaporwaveColors.neonPurple
            case .hardware: return VaporwaveColors.coral
            case .streaming: return VaporwaveColors.neonPink
            case .settings: return VaporwaveColors.textSecondary
            }
        }

        var shortcut: String {
            switch self {
            case .palace: return "1"
            case .daw: return "2"
            case .session: return "3"
            case .video: return "4"
            case .vj: return "5"
            case .nodes: return "6"
            case .midi: return "7"
            case .mixing: return "8"
            case .ai: return "9"
            case .hardware: return "0"
            case .streaming: return "-"
            case .settings: return ","
            }
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                VaporwaveGradients.background
                    .ignoresSafeArea()

                // Main Layout
                #if os(iOS)
                if geometry.size.width > 768 {
                    // iPad - Desktop-style layout
                    desktopLayout
                } else {
                    // iPhone - Tab-based layout
                    mobileLayout
                }
                #elseif os(macOS)
                desktopLayout
                #elseif os(visionOS)
                visionOSLayout
                #elseif os(tvOS)
                tvOSLayout
                #else
                desktopLayout
                #endif
            }
        }
        .sheet(isPresented: $showSettings) {
            VaporwaveSettings()
                .environmentObject(healthKitManager)
                .environmentObject(audioEngine)
        }
        .sheet(isPresented: $showSearch) {
            CommandPaletteView(
                searchQuery: $searchQuery,
                onSelect: handleCommand
            )
        }
    }

    // MARK: - Desktop Layout (iPad/Mac/Vision Pro)

    private var desktopLayout: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar

            // Main Content Area
            HStack(spacing: 0) {
                // Sidebar
                if sidebarExpanded {
                    sidebar
                        .frame(width: 220)
                        .transition(.move(edge: .leading))
                }

                // Workspace Content
                workspaceContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Transport Bar
            transportBar
        }
    }

    // MARK: - Mobile Layout (iPhone)

    private var mobileLayout: some View {
        VStack(spacing: 0) {
            // Top Status Bar
            mobileStatusBar

            // Content
            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Tab Bar
            mobileTabBar
        }
    }

    // MARK: - visionOS Layout

    private var visionOSLayout: some View {
        ZStack {
            // Floating workspace content
            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating toolbar
            VStack {
                Spacer()

                floatingToolbar
                    .padding()
            }
        }
    }

    // MARK: - tvOS Layout

    private var tvOSLayout: some View {
        VStack(spacing: 0) {
            // Top navigation
            tvOSTopNav

            // Content
            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: VaporwaveSpacing.md) {
            // Sidebar Toggle
            Button(action: {
                withAnimation(reduceMotion ? nil : VaporwaveAnimation.smooth) {
                    sidebarExpanded.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sidebarExpanded ? "Collapse sidebar" : "Expand sidebar")
            .accessibilityHint("Toggles the navigation sidebar")

            // Logo
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20))
                    .foregroundColor(VaporwaveColors.neonPink)
                    .neonGlow(color: VaporwaveColors.neonPink, radius: 8)

                Text("ECHOELMUSIC")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .tracking(2)
            }

            Spacer()

            // Workspace Tabs
            workspaceTabs

            Spacer()

            // Bio Status
            bioStatusIndicator

            // Search
            Button(action: { showSearch = true }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Search")
            .accessibilityHint("Search workspaces and controls. Command-K")

            // Quick Actions
            Button(action: { showQuickActions.toggle() }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(VaporwaveColors.neonCyan)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQuickActions) {
                QuickActionsMenu(onAction: handleQuickAction)
            }
            .accessibilityLabel("Quick actions")
            .accessibilityHint("Create new session, add track, or import")
        }
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.vertical, VaporwaveSpacing.md)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [currentWorkspace.color.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 2)
                        .offset(y: 20),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Workspace Tabs

    private var workspaceTabs: some View {
        HStack(spacing: 0) {
            ForEach([Workspace.palace, .daw, .session, .video, .vj, .nodes, .ai], id: \.self) { workspace in
                workspaceTab(workspace)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
        )
    }

    private func workspaceTab(_ workspace: Workspace) -> some View {
        Button(action: {
            withAnimation(VaporwaveAnimation.smooth) {
                currentWorkspace = workspace
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: workspace.icon)
                    .font(.system(size: 12))

                if currentWorkspace == workspace {
                    Text(workspace.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(currentWorkspace == workspace ? .white : VaporwaveColors.textSecondary)
            .padding(.horizontal, currentWorkspace == workspace ? 14 : 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentWorkspace == workspace ? workspace.color.opacity(0.8) : .clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workspace.rawValue) workspace")
        .accessibilityValue(currentWorkspace == workspace ? "Selected" : "")
        .accessibilityHint("Switch to \(workspace.rawValue)")
    }

    // MARK: - Bio Status Indicator

    private var bioStatusIndicator: some View {
        HStack(spacing: VaporwaveSpacing.md) {
            // Heart Rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(VaporwaveColors.heartRate)

                Text("\(heartRate)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate: \(heartRate) BPM")

            // Coherence
            HStack(spacing: 4) {
                Image(systemName: coherenceIcon)
                    .font(.system(size: 10))
                    .foregroundColor(coherenceColor)

                Circle()
                    .fill(coherenceColor)
                    .frame(width: 8, height: 8)
                    .neonGlow(color: coherenceColor, radius: 4)
                    .accessibilityHidden(true)

                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coherence: \(coherenceLabel), \(Int(coherence * 100)) percent")
        }
        .padding(.horizontal, VaporwaveSpacing.md)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(coherenceColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var coherenceLabel: String {
        if coherence > 0.7 { return "High" }
        else if coherence > 0.4 { return "Medium" }
        else { return "Low" }
    }

    private var coherenceIcon: String {
        if coherence > 0.7 { return "star.fill" }
        else if coherence > 0.4 { return "checkmark.circle.fill" }
        else { return "exclamationmark.circle.fill" }
    }

    private var coherenceColor: Color {
        if coherence > 0.7 {
            return VaporwaveColors.coherenceHigh
        } else if coherence > 0.4 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceLow
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Workspace List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: VaporwaveSpacing.xs) {
                    ForEach(Workspace.allCases) { workspace in
                        sidebarItem(workspace)
                    }
                }
                .padding(VaporwaveSpacing.md)
            }

            Divider()
                .background(VaporwaveColors.textTertiary.opacity(0.2))

            // Bottom Section - User & Help
            VStack(spacing: VaporwaveSpacing.sm) {
                sidebarBottomItem(icon: "questionmark.circle", label: "Help", action: {})
                sidebarBottomItem(icon: "arrow.up.circle", label: "Upgrade Pro", action: {})
            }
            .padding(VaporwaveSpacing.md)
        }
        .background(Color.black.opacity(0.4))
    }

    private func sidebarItem(_ workspace: Workspace) -> some View {
        Button(action: {
            withAnimation(VaporwaveAnimation.smooth) {
                currentWorkspace = workspace
            }
        }) {
            HStack(spacing: VaporwaveSpacing.md) {
                Image(systemName: workspace.icon)
                    .font(.system(size: 16))
                    .foregroundColor(currentWorkspace == workspace ? workspace.color : VaporwaveColors.textTertiary)
                    .frame(width: 24)

                Text(workspace.rawValue)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(currentWorkspace == workspace ? VaporwaveColors.textPrimary : VaporwaveColors.textSecondary)

                Spacer()

                Text(workspace.shortcut)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentWorkspace == workspace ? workspace.color.opacity(0.2) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentWorkspace == workspace ? workspace.color.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workspace.rawValue) workspace")
        .accessibilityValue(currentWorkspace == workspace ? "Selected" : "")
        .accessibilityHint("Shortcut: \(workspace.shortcut)")
    }

    private func sidebarBottomItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: VaporwaveSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .frame(width: 20)

                Text(label)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Workspace Content

    @ViewBuilder
    private var workspaceContent: some View {
        // Extracted to WorkspaceContentRouter for better modularity
        WorkspaceContentRouter(workspace: currentWorkspace)
            .environmentObject(healthKitManager)
            .environmentObject(audioEngine)
            .environmentObject(microphoneManager)
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Playback Controls
            HStack(spacing: VaporwaveSpacing.md) {
                transportButton(icon: "backward.end.fill") { }
                transportButton(icon: "backward.fill") { }

                Button(action: { isPlaying.toggle() }) {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan)
                            .frame(width: 40, height: 40)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .neonGlow(color: isPlaying ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan, radius: 8)
                }
                .buttonStyle(.plain)

                transportButton(icon: "forward.fill") { }
                transportButton(icon: "forward.end.fill") { }

                transportButton(icon: "stop.fill") { isPlaying = false }
                transportButton(icon: "record.circle", color: VaporwaveColors.neonPink) { }
            }

            Divider()
                .frame(height: 24)
                .background(VaporwaveColors.textTertiary.opacity(0.3))

            // Time Display
            VStack(spacing: 0) {
                Text("00:00:00:00")
                    .font(.system(size: 18, weight: .light, design: .monospaced))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text("TIMECODE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .tracking(2)
            }

            Divider()
                .frame(height: 24)
                .background(VaporwaveColors.textTertiary.opacity(0.3))

            // BPM
            HStack(spacing: VaporwaveSpacing.sm) {
                Button(action: { bpm = max(20, bpm - 1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10))
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    Text(String(format: "%.1f", bpm))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(VaporwaveColors.neonPurple)

                    Text("BPM")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .tracking(2)
                }

                Button(action: { bpm = min(300, bpm + 1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )

            Spacer()

            // Right Side Controls
            HStack(spacing: VaporwaveSpacing.md) {
                // Metronome
                transportButton(icon: "metronome", color: VaporwaveColors.textSecondary) { }

                // Loop
                transportButton(icon: "repeat", color: VaporwaveColors.neonCyan) { }

                // MIDI
                transportButton(icon: "pianokeys", color: VaporwaveColors.textSecondary) { }

                // CPU
                VStack(spacing: 0) {
                    Text("12%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(VaporwaveColors.coherenceHigh)

                    Text("CPU")
                        .font(.system(size: 6))
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.vertical, VaporwaveSpacing.md)
        .background(Color.black.opacity(0.9))
    }

    private func transportButton(icon: String, color: Color = VaporwaveColors.textSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mobile Components

    private var mobileStatusBar: some View {
        HStack(spacing: VaporwaveSpacing.md) {
            // Logo
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18))
                .foregroundColor(VaporwaveColors.neonPink)

            Text(currentWorkspace.rawValue.uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(VaporwaveColors.textPrimary)
                .tracking(2)

            Spacer()

            // Bio
            HStack(spacing: 4) {
                Circle()
                    .fill(coherenceColor)
                    .frame(width: 8, height: 8)

                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }

            // Theme Toggle (Dark/Light)
            ThemeToggleButton()

            // Settings
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
        }
        .padding(.horizontal, VaporwaveSpacing.md)
        .padding(.vertical, VaporwaveSpacing.sm)
        .background(Color.black.opacity(0.8))
    }

    private var mobileTabBar: some View {
        HStack(spacing: 0) {
            ForEach([Workspace.palace, .daw, .session, .vj, .ai], id: \.self) { workspace in
                mobileTabButton(workspace)
            }
        }
        .padding(.top, VaporwaveSpacing.sm)
        .padding(.bottom, VaporwaveSpacing.lg)
        .background(Color.black.opacity(0.9))
    }

    private func mobileTabButton(_ workspace: Workspace) -> some View {
        Button(action: {
            withAnimation(VaporwaveAnimation.smooth) {
                currentWorkspace = workspace
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: currentWorkspace == workspace ? workspace.filledIcon : workspace.icon)
                    .font(.system(size: 20))
                    .foregroundColor(currentWorkspace == workspace ? workspace.color : VaporwaveColors.textTertiary)
                    .neonGlow(color: currentWorkspace == workspace ? workspace.color : .clear, radius: 6)

                Text(workspace.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(currentWorkspace == workspace ? workspace.color : VaporwaveColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating Toolbar (visionOS)

    private var floatingToolbar: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            ForEach([Workspace.palace, .daw, .session, .video, .vj, .nodes, .ai], id: \.self) { workspace in
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        currentWorkspace = workspace
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: workspace.icon)
                            .font(.system(size: 24))
                            .foregroundColor(currentWorkspace == workspace ? workspace.color : VaporwaveColors.textSecondary)

                        Text(workspace.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(currentWorkspace == workspace ? workspace.color : VaporwaveColors.textTertiary)
                    }
                    .padding(VaporwaveSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentWorkspace == workspace ? workspace.color.opacity(0.2) : Color.black.opacity(0.4))
                    )
                    .neonGlow(color: currentWorkspace == workspace ? workspace.color : .clear, radius: 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VaporwaveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(VaporwaveColors.textTertiary.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - tvOS Navigation

    private var tvOSTopNav: some View {
        HStack(spacing: VaporwaveSpacing.xl) {
            // Logo
            HStack(spacing: VaporwaveSpacing.md) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32))
                    .foregroundColor(VaporwaveColors.neonPink)

                Text("ECHOELMUSIC")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(VaporwaveColors.textPrimary)
            }

            Spacer()

            // Workspace Selector
            ForEach([Workspace.palace, .daw, .session, .vj, .ai], id: \.self) { workspace in
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        currentWorkspace = workspace
                    }
                }) {
                    Text(workspace.rawValue)
                        .font(.system(size: 18, weight: currentWorkspace == workspace ? .bold : .regular))
                        .foregroundColor(currentWorkspace == workspace ? workspace.color : VaporwaveColors.textSecondary)
                        .padding(.horizontal, VaporwaveSpacing.lg)
                        .padding(.vertical, VaporwaveSpacing.md)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Bio Status
            HStack(spacing: VaporwaveSpacing.md) {
                Circle()
                    .fill(coherenceColor)
                    .frame(width: 16, height: 16)

                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
        }
        .padding(VaporwaveSpacing.xl)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Helpers

    private func handleCommand(_ command: String) {
        showSearch = false
        // Handle command palette selection
    }

    private func handleQuickAction(_ action: QuickAction) {
        showQuickActions = false
        // Handle quick action
    }
}

// MARK: - Command Palette

struct CommandPaletteView: View {
    @Binding var searchQuery: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) var dismiss

    private let commands = [
        ("New Project", "doc.badge.plus", "Create a new project"),
        ("Open Project", "folder", "Open existing project"),
        ("Save Project", "square.and.arrow.down", "Save current project"),
        ("Export Audio", "square.and.arrow.up", "Export audio file"),
        ("Export Video", "film", "Export video file"),
        ("Add Track", "plus.rectangle.on.rectangle", "Add new track"),
        ("Add Instrument", "pianokeys", "Add instrument"),
        ("Add Effect", "waveform.badge.plus", "Add audio effect"),
        ("Toggle Bio-Reactive", "heart.circle", "Toggle bio-reactive mode"),
        ("Start Recording", "record.circle", "Begin recording"),
        ("Open MIDI Settings", "cable.connector", "Configure MIDI"),
        ("Open Audio Settings", "slider.horizontal.3", "Configure audio routing"),
        ("Open AI Tools", "brain.head.profile", "Open AI assistant"),
        ("Toggle Full Screen", "arrow.up.left.and.arrow.down.right", "Toggle full screen mode"),
    ]

    var filteredCommands: [(String, String, String)] {
        if searchQuery.isEmpty {
            return commands
        }
        return commands.filter { $0.0.lowercased().contains(searchQuery.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            HStack(spacing: VaporwaveSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.textTertiary)

                TextField("Search commands...", text: $searchQuery)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { dismiss() }) {
                    Text("ESC")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(VaporwaveSpacing.md)
            .background(Color.black.opacity(0.6))

            Divider()
                .background(VaporwaveColors.textTertiary.opacity(0.2))

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCommands, id: \.0) { command in
                        Button(action: { onSelect(command.0) }) {
                            HStack(spacing: VaporwaveSpacing.md) {
                                Image(systemName: command.1)
                                    .font(.system(size: 16))
                                    .foregroundColor(VaporwaveColors.neonCyan)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.0)
                                        .font(VaporwaveTypography.body())
                                        .foregroundColor(VaporwaveColors.textPrimary)

                                    Text(command.2)
                                        .font(VaporwaveTypography.caption())
                                        .foregroundColor(VaporwaveColors.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(VaporwaveSpacing.md)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(VaporwaveColors.textTertiary.opacity(0.1))
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(VaporwaveColors.deepBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(VaporwaveColors.neonCyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quick Actions Menu

enum QuickAction: String, CaseIterable {
    case newProject = "New Project"
    case addTrack = "Add Track"
    case addInstrument = "Add Instrument"
    case addEffect = "Add Effect"
    case startSession = "Start Session"
    case toggleBio = "Toggle Bio Mode"
}

struct QuickActionsMenu: View {
    let onAction: (QuickAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Button(action: { onAction(action) }) {
                    HStack(spacing: VaporwaveSpacing.md) {
                        Image(systemName: iconFor(action))
                            .font(.system(size: 14))
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .frame(width: 20)

                        Text(action.rawValue)
                            .font(VaporwaveTypography.body())
                            .foregroundColor(VaporwaveColors.textPrimary)

                        Spacer()
                    }
                    .padding(VaporwaveSpacing.md)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if action != QuickAction.allCases.last {
                    Divider()
                        .background(VaporwaveColors.textTertiary.opacity(0.2))
                }
            }
        }
        .frame(width: 200)
        .background(VaporwaveColors.deepBlack)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VaporwaveColors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    private func iconFor(_ action: QuickAction) -> String {
        switch action {
        case .newProject: return "doc.badge.plus"
        case .addTrack: return "plus.rectangle.on.rectangle"
        case .addInstrument: return "pianokeys"
        case .addEffect: return "waveform.badge.plus"
        case .startSession: return "play.circle"
        case .toggleBio: return "heart.circle"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Desktop") {
    MainNavigationHub()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
        .environmentObject(MicrophoneManager())
        .environmentObject(RecordingEngine())
        .frame(width: 1400, height: 900)
}
#endif

#if DEBUG
#Preview("Mobile") {
    MainNavigationHub()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
        .environmentObject(MicrophoneManager())
        .environmentObject(RecordingEngine())
        .frame(width: 390, height: 844)
}
#endif
