import SwiftUI

// MARK: - Main Navigation Hub
// Unified workspace navigation for Echoelmusic — Monochrome Production Interface
// E + Wellen, Schwarz mit Grautönen — Connects all professional views

struct MainNavigationHub: View {

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var recordingEngine: RecordingEngine

    // MARK: - Live Engine State

    @EnvironmentObject var unifiedControlHub: UnifiedControlHub
    @EnvironmentObject var healthKitEngine: UnifiedHealthKitEngine

    // MARK: - UI State

    @State private var currentWorkspace: Workspace = .daw
    @State private var sidebarExpanded = true
    @State private var showQuickActions = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var playbackSeconds: Double = 0
    @State private var playbackTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Live Computed Properties (no stale state)

    /// Live coherence from HealthKit (0.0-1.0)
    private var coherence: Double {
        healthKitEngine.coherence
    }

    /// Live heart rate from HealthKit
    private var heartRate: Int {
        Int(healthKitEngine.heartRate)
    }

    /// Live playback state from AudioEngine
    private var isPlaying: Bool {
        audioEngine.isRunning
    }

    /// Live BPM from EchoelCreativeWorkspace
    private var bpm: Double {
        EchoelCreativeWorkspace.shared.globalBPM
    }

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
            case .palace: return EchoelBrand.primary
            case .daw: return EchoelBrand.sky
            case .session: return EchoelBrand.violet
            case .video: return EchoelBrand.coral
            case .vj: return EchoelBrand.emerald
            case .nodes: return EchoelBrand.violet
            case .midi: return EchoelBrand.amber
            case .mixing: return EchoelBrand.sky
            case .ai: return EchoelBrand.violet
            case .hardware: return EchoelBrand.coral
            case .streaming: return EchoelBrand.rose
            case .settings: return EchoelBrand.textSecondary
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
                // Background — true black
                EchoelBrand.bgDeep
                    .ignoresSafeArea()

                // Main Layout
                #if os(iOS)
                if geometry.size.width > 768 {
                    desktopLayout
                } else {
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
            topBar

            HStack(spacing: 0) {
                if sidebarExpanded {
                    sidebar
                        .frame(width: 220)
                        .transition(.move(edge: .leading))
                }

                // Workspace Content
                workspaceContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            transportBar
        }
    }

    // MARK: - Mobile Layout (iPhone)

    private var mobileLayout: some View {
        VStack(spacing: 0) {
            mobileStatusBar

            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            mobileTabBar
        }
    }

    // MARK: - visionOS Layout

    private var visionOSLayout: some View {
        ZStack {
            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            tvOSTopNav

            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: EchoelSpacing.md) {
            // Sidebar Toggle
            Button(action: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: EchoelAnimation.smooth)) {
                    sidebarExpanded.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sidebarExpanded ? "Collapse sidebar" : "Expand sidebar")
            .accessibilityHint("Toggles the navigation sidebar")

            // Logo — E + Wellen
            HStack(spacing: EchoelSpacing.sm) {
                ELetterShape()
                    .stroke(
                        EchoelBrand.primary,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 14, height: 18)

                Text("ECHOELMUSIC")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(EchoelBrand.textPrimary)
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
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Search")
            .accessibilityHint("Search workspaces and controls. Command-K")

            // Quick Actions
            Button(action: { showQuickActions.toggle() }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(EchoelBrand.primary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQuickActions) {
                QuickActionsMenu(onAction: handleQuickAction)
            }
            .accessibilityLabel("Quick actions")
            .accessibilityHint("Create new session, add track, or import")
        }
        .padding(.horizontal, EchoelSpacing.lg)
        .padding(.vertical, EchoelSpacing.md)
        .background(
            Rectangle()
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Workspace Tabs

    private var workspaceTabs: some View {
        HStack(spacing: 0) {
            // Video + Music Production prioritized
            ForEach([Workspace.daw, .video, .session, .palace, .vj, .nodes, .ai], id: \.self) { workspace in
                workspaceTab(workspace)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(EchoelBrand.bgSurface)
        )
    }

    private func workspaceTab(_ workspace: Workspace) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
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
            .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
            .padding(.horizontal, currentWorkspace == workspace ? 14 : 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentWorkspace == workspace ? EchoelBrand.bgElevated : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        currentWorkspace == workspace ? EchoelBrand.borderActive : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workspace.rawValue) workspace")
        .accessibilityValue(currentWorkspace == workspace ? "Selected" : "")
        .accessibilityHint("Switch to \(workspace.rawValue)")
    }

    // MARK: - Bio Status Indicator

    private var bioStatusIndicator: some View {
        HStack(spacing: EchoelSpacing.md) {
            // Heart Rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(EchoelBrand.rose)

                Text("\(heartRate)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textPrimary)
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
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)

                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coherence: \(coherenceLabel), \(Int(coherence * 100)) percent")
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(EchoelBrand.border, lineWidth: 1)
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
            return EchoelBrand.coherenceHigh
        } else if coherence > 0.4 {
            return EchoelBrand.coherenceMedium
        } else {
            return EchoelBrand.coherenceLow
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: EchoelSpacing.xs) {
                    ForEach(Workspace.allCases) { workspace in
                        sidebarItem(workspace)
                    }
                }
                .padding(EchoelSpacing.md)
            }

            Divider()
                .background(EchoelBrand.border)

            VStack(spacing: EchoelSpacing.sm) {
                sidebarBottomItem(icon: "questionmark.circle", label: "Help", action: {})
                sidebarBottomItem(icon: "arrow.up.circle", label: "Upgrade Pro", action: {})
            }
            .padding(EchoelSpacing.md)
        }
        .background(EchoelBrand.bgSurface.opacity(0.5))
    }

    private func sidebarItem(_ workspace: Workspace) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                currentWorkspace = workspace
            }
        }) {
            HStack(spacing: EchoelSpacing.md) {
                Image(systemName: workspace.icon)
                    .font(.system(size: 16))
                    .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
                    .frame(width: 24)

                Text(workspace.rawValue)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)

                Spacer()

                Text(workspace.shortcut)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(EchoelBrand.bgElevated)
                    )
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentWorkspace == workspace ? EchoelBrand.bgElevated : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentWorkspace == workspace ? EchoelBrand.borderActive : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workspace.rawValue) workspace")
        .accessibilityValue(currentWorkspace == workspace ? "Selected" : "")
        .accessibilityHint("Shortcut: \(workspace.shortcut)")
    }

    private func sidebarBottomItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: EchoelSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .frame(width: 20)

                Text(label)
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Workspace Content

    @ViewBuilder
    private var workspaceContent: some View {
        WorkspaceContentRouter(workspace: currentWorkspace)
            .environmentObject(healthKitManager)
            .environmentObject(audioEngine)
            .environmentObject(microphoneManager)
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: EchoelSpacing.lg) {
            // Playback Controls
            HStack(spacing: EchoelSpacing.md) {
                transportButton(icon: "backward.end.fill") { }
                transportButton(icon: "backward.fill") { }

                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? EchoelBrand.primary : EchoelBrand.bgElevated)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(EchoelBrand.primary.opacity(0.4), lineWidth: 1)
                            )

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isPlaying ? EchoelBrand.bgDeep : EchoelBrand.primary)
                    }
                }
                .buttonStyle(.plain)

                transportButton(icon: "forward.fill") { }
                transportButton(icon: "forward.end.fill") { }

                transportButton(icon: "stop.fill") { stopPlayback() }
                transportButton(icon: "record.circle", color: EchoelBrand.coral) { toggleRecording() }
            }

            Divider()
                .frame(height: 24)
                .background(EchoelBrand.border)

            // Time Display — live timecode
            VStack(spacing: 0) {
                Text(formatTimecode(playbackSeconds))
                    .font(.system(size: 18, weight: .light, design: .monospaced))
                    .foregroundColor(EchoelBrand.textPrimary)

                Text("TIMECODE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .tracking(2)
            }

            Divider()
                .frame(height: 24)
                .background(EchoelBrand.border)

            // BPM
            HStack(spacing: EchoelSpacing.sm) {
                Button(action: { adjustBPM(by: -1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10))
                        .foregroundColor(EchoelBrand.textTertiary)
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    Text(String(format: "%.1f", bpm))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(EchoelBrand.textPrimary)

                    Text("BPM")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(EchoelBrand.textTertiary)
                        .tracking(2)
                }

                Button(action: { adjustBPM(by: 1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundColor(EchoelBrand.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(EchoelBrand.bgElevated)
            )

            Spacer()

            // Right Side Controls
            HStack(spacing: EchoelSpacing.md) {
                // Metronome
                Button(action: { toggleMetronome() }) {
                    Image(systemName: metronomeActive ? "metronome.fill" : "metronome")
                        .font(.system(size: 14))
                        .foregroundColor(metronomeActive ? EchoelBrand.amber : EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // Loop Mode
                Button(action: { toggleLoopMode() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 14))
                        .foregroundColor(loopActive ? EchoelBrand.primary : EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // MIDI
                Button(action: { currentWorkspace = .midi }) {
                    Image(systemName: "pianokeys")
                        .font(.system(size: 14))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                // CPU
                VStack(spacing: 0) {
                    Text(String(format: "%.0f%%", unifiedControlHub.controlLoopFrequency / 60.0 * 100.0))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(unifiedControlHub.controlLoopFrequency > 50 ? EchoelBrand.coherenceHigh : EchoelBrand.coherenceMedium)

                    Text("CPU")
                        .font(.system(size: 6))
                        .foregroundColor(EchoelBrand.textTertiary)
                }
            }
        }
        .padding(.horizontal, EchoelSpacing.lg)
        .padding(.vertical, EchoelSpacing.md)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    private func transportButton(icon: String, color: Color = EchoelBrand.textSecondary, action: @escaping () -> Void) -> some View {
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
        HStack(spacing: EchoelSpacing.md) {
            // Logo — E letter
            ELetterShape()
                .stroke(
                    EchoelBrand.primary,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 12, height: 16)

            Text(currentWorkspace.rawValue.uppercased())
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EchoelBrand.textPrimary)
                .tracking(2)

            Spacer()

            // Bio
            HStack(spacing: 4) {
                Circle()
                    .fill(coherenceColor)
                    .frame(width: 6, height: 6)

                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textSecondary)
            }

            // Theme Toggle (Dark/Light)
            ThemeToggleButton()

            // Settings
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(EchoelBrand.textTertiary)
            }
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(EchoelBrand.bgSurface)
    }

    private var mobileTabBar: some View {
        HStack(spacing: 0) {
            // Video + Music Production prioritized
            ForEach([Workspace.daw, .video, .palace, .session, .ai], id: \.self) { workspace in
                mobileTabButton(workspace)
            }
        }
        .padding(.top, EchoelSpacing.sm)
        .padding(.bottom, EchoelSpacing.lg)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    private func mobileTabButton(_ workspace: Workspace) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                currentWorkspace = workspace
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: currentWorkspace == workspace ? workspace.filledIcon : workspace.icon)
                    .font(.system(size: 20))
                    .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)

                Text(workspace.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating Toolbar (visionOS)

    private var floatingToolbar: some View {
        HStack(spacing: EchoelSpacing.lg) {
            // Video + Music Production prioritized
            ForEach([Workspace.daw, .video, .session, .palace, .vj, .nodes, .ai], id: \.self) { workspace in
                Button(action: {
                    withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                        currentWorkspace = workspace
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: workspace.icon)
                            .font(.system(size: 24))
                            .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)

                        Text(workspace.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
                    }
                    .padding(EchoelSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentWorkspace == workspace ? EchoelBrand.bgElevated : EchoelBrand.bgSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(currentWorkspace == workspace ? EchoelBrand.borderActive : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EchoelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(EchoelBrand.bgSurface.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
        )
    }

    // MARK: - tvOS Navigation

    private var tvOSTopNav: some View {
        HStack(spacing: EchoelSpacing.xl) {
            // Logo
            HStack(spacing: EchoelSpacing.md) {
                ELetterShape()
                    .stroke(
                        EchoelBrand.primary,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 24, height: 32)

                Text("ECHOELMUSIC")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(EchoelBrand.textPrimary)
                    .tracking(3)
            }

            Spacer()

            // Workspace Selector
            // Video + Music Production prioritized
            ForEach([Workspace.daw, .video, .palace, .session, .ai], id: \.self) { workspace in
                Button(action: {
                    withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                        currentWorkspace = workspace
                    }
                }) {
                    Text(workspace.rawValue)
                        .font(.system(size: 18, weight: currentWorkspace == workspace ? .semibold : .regular))
                        .foregroundColor(currentWorkspace == workspace ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)
                        .padding(.horizontal, EchoelSpacing.lg)
                        .padding(.vertical, EchoelSpacing.md)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Bio Status
            HStack(spacing: EchoelSpacing.md) {
                Circle()
                    .fill(coherenceColor)
                    .frame(width: 12, height: 12)

                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textPrimary)
            }
        }
        .padding(EchoelSpacing.xl)
        .background(EchoelBrand.bgSurface)
    }

    // MARK: - Live Engine Computed Properties

    /// Metronome state from ProSessionEngine
    private var metronomeActive: Bool {
        EchoelCreativeWorkspace.shared.proSession.metronomeEnabled
    }

    /// Loop mode
    @State private var loopActive: Bool = false

    // MARK: - Transport Actions

    private func toggleMetronome() {
        EchoelCreativeWorkspace.shared.proSession.metronomeEnabled.toggle()
        EchoelCreativeWorkspace.shared.bpmGrid.metronomeEnabled = EchoelCreativeWorkspace.shared.proSession.metronomeEnabled
    }

    private func toggleLoopMode() {
        loopActive.toggle()
        let workspace = EchoelCreativeWorkspace.shared

        for trackIndex in workspace.proSession.tracks.indices {
            for sceneIndex in workspace.proSession.scenes.indices {
                if var clip = workspace.proSession.tracks[trackIndex].clips[sceneIndex] {
                    clip.loopEnabled = loopActive
                    workspace.proSession.tracks[trackIndex].clips[sceneIndex] = clip
                }
            }
        }
    }

    private func togglePlayback() {
        if audioEngine.isRunning {
            audioEngine.stop()
            healthKitEngine.stopStreaming()
            stopTimecode()
        } else {
            audioEngine.start()
            if healthKitEngine.isAuthorized {
                healthKitEngine.startStreaming()
            }
            startTimecode()
        }
        EchoelCreativeWorkspace.shared.togglePlayback()
    }

    private func stopPlayback() {
        audioEngine.stop()
        healthKitEngine.stopStreaming()
        stopTimecode()
        playbackSeconds = 0
        if EchoelCreativeWorkspace.shared.isPlaying {
            EchoelCreativeWorkspace.shared.togglePlayback()
        }
    }

    // MARK: - Timecode

    private func startTimecode() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                playbackSeconds += 1.0 / 30.0
            }
        }
    }

    private func stopTimecode() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func formatTimecode(_ totalSeconds: Double) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let frames = Int((totalSeconds - Double(Int(totalSeconds))) * 30)
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    private func toggleRecording() {
        do {
            if recordingEngine.isRecording {
                try recordingEngine.stopRecording()
            } else {
                try recordingEngine.startRecording()
            }
        } catch {
            log.warning("Recording toggle failed: \(error.localizedDescription)", category: .audio)
        }
    }

    private func adjustBPM(by delta: Double) {
        let newBPM = max(20, min(300, bpm + delta))
        EchoelCreativeWorkspace.shared.setGlobalBPM(newBPM)
        audioEngine.setTempo(Float(newBPM))
    }

    // MARK: - Command & Action Handlers

    private func handleCommand(_ command: String) {
        showSearch = false

        switch command {
        case "New Project":
            EchoelCreativeWorkspace.shared.newSession(mode: .audioVideo, bpm: bpm)
        case "Save Project":
            CrashSafeStatePersistence.shared.saveState(SessionState())
        case "Add Track":
            _ = EchoelCreativeWorkspace.shared.proMixer.addChannel(name: "Track \(EchoelCreativeWorkspace.shared.proMixer.channels.count + 1)", type: .audio)
        case "Add Instrument":
            currentWorkspace = .daw
        case "Add Effect":
            currentWorkspace = .nodes
        case "Toggle Bio-Reactive":
            Task {
                do {
                    try await unifiedControlHub.enableBiometricMonitoring()
                } catch {
                    log.warning("Biometric monitoring not available: \(error.localizedDescription)", category: .system)
                }
            }
        case "Start Recording":
            toggleRecording()
        case "Open MIDI Settings":
            currentWorkspace = .midi
        case "Open Audio Settings":
            currentWorkspace = .mixing
        case "Open AI Tools":
            currentWorkspace = .ai
        case "Export Audio", "Export Video":
            currentWorkspace = .streaming
        case "Open Project":
            currentWorkspace = .session
        default:
            log.info("Command: \(command)", category: .system)
        }
    }

    private func handleQuickAction(_ action: QuickAction) {
        showQuickActions = false

        switch action {
        case .newProject:
            EchoelCreativeWorkspace.shared.newSession(mode: .audioVideo, bpm: bpm)
        case .addTrack:
            _ = EchoelCreativeWorkspace.shared.proMixer.addChannel(name: "Track \(EchoelCreativeWorkspace.shared.proMixer.channels.count + 1)", type: .audio)
        case .addInstrument:
            currentWorkspace = .daw
        case .addEffect:
            currentWorkspace = .nodes
        case .startSession:
            togglePlayback()
        case .toggleBio:
            Task {
                do {
                    try await unifiedControlHub.enableBiometricMonitoring()
                } catch {
                    log.warning("Bio mode not available: \(error.localizedDescription)", category: .system)
                }
            }
        }
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
            HStack(spacing: EchoelSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(EchoelBrand.textTertiary)

                TextField("Search commands...", text: $searchQuery)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(EchoelBrand.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { dismiss() }) {
                    Text("ESC")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(EchoelBrand.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(EchoelBrand.bgElevated)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(EchoelSpacing.md)
            .background(EchoelBrand.bgSurface)

            Divider()
                .background(EchoelBrand.border)

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCommands, id: \.0) { command in
                        Button(action: { onSelect(command.0) }) {
                            HStack(spacing: EchoelSpacing.md) {
                                Image(systemName: command.1)
                                    .font(.system(size: 16))
                                    .foregroundColor(EchoelBrand.primary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.0)
                                        .font(EchoelBrandFont.body())
                                        .foregroundColor(EchoelBrand.textPrimary)

                                    Text(command.2)
                                        .font(EchoelBrandFont.caption())
                                        .foregroundColor(EchoelBrand.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(EchoelSpacing.md)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(EchoelBrand.border)
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.lg)
                .fill(EchoelBrand.bgDeep)
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.lg)
                        .stroke(EchoelBrand.borderActive, lineWidth: 1)
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
                    HStack(spacing: EchoelSpacing.md) {
                        Image(systemName: iconFor(action))
                            .font(.system(size: 14))
                            .foregroundColor(EchoelBrand.primary)
                            .frame(width: 20)

                        Text(action.rawValue)
                            .font(EchoelBrandFont.body())
                            .foregroundColor(EchoelBrand.textPrimary)

                        Spacer()
                    }
                    .padding(EchoelSpacing.md)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if action != QuickAction.allCases.last {
                    Divider()
                        .background(EchoelBrand.border)
                }
            }
        }
        .frame(width: 200)
        .background(EchoelBrand.bgDeep)
        .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .stroke(EchoelBrand.border, lineWidth: 1)
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
    let audioEngine = AudioEngine()
    MainNavigationHub()
        .environmentObject(HealthKitManager())
        .environmentObject(audioEngine)
        .environmentObject(MicrophoneManager())
        .environmentObject(RecordingEngine())
        .environmentObject(UnifiedControlHub(audioEngine: audioEngine))
        .environmentObject(UnifiedHealthKitEngine.shared)
        .frame(width: 1400, height: 900)
}
#endif

#if DEBUG
#Preview("Mobile") {
    let audioEngine = AudioEngine()
    MainNavigationHub()
        .environmentObject(HealthKitManager())
        .environmentObject(audioEngine)
        .environmentObject(MicrophoneManager())
        .environmentObject(RecordingEngine())
        .environmentObject(UnifiedControlHub(audioEngine: audioEngine))
        .environmentObject(UnifiedHealthKitEngine.shared)
        .frame(width: 390, height: 844)
}
#endif
