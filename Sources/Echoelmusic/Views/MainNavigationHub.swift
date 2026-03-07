#if canImport(SwiftUI)
import SwiftUI

/// Main navigation — DAW + Video workspaces
struct MainNavigationHub: View {

    @Environment(AudioEngine.self) var audioEngine
    @Environment(MicrophoneManager.self) var microphoneManager
    @Environment(RecordingEngine.self) var recordingEngine
    @Environment(ThemeManager.self) var themeManager

    @State private var currentTab: Tab = .daw
    @State private var sidebarExpanded = true
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Tab: String, CaseIterable, Identifiable {
        case daw = "DAW"
        case live = "Live"
        case synth = "Synth"
        case fx = "FX"
        case video = "Video"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .daw: return "pianokeys"
            case .live: return "square.grid.3x3"
            case .synth: return "waveform"
            case .fx: return "waveform.path.ecg"
            case .video: return "film"
            }
        }

        var filledIcon: String {
            switch self {
            case .daw: return "pianokeys.inverse"
            case .live: return "square.grid.3x3.fill"
            case .synth: return "waveform.circle.fill"
            case .fx: return "waveform.path.ecg.rectangle.fill"
            case .video: return "film.fill"
            }
        }

        var color: Color {
            switch self {
            case .daw: return EchoelBrand.sky
            case .live: return EchoelBrand.emerald
            case .synth: return EchoelBrand.primary
            case .fx: return EchoelBrand.violet
            case .video: return EchoelBrand.coral
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                EchoelBrand.bgDeep
                    .ignoresSafeArea()

                if geometry.size.width > 768 {
                    desktopLayout
                } else {
                    mobileLayout
                }
            }
        }
        .onAppear {
            // Ensure a session exists for DAW
            if recordingEngine.currentSession == nil {
                _ = recordingEngine.createSession(name: "New Project", template: .custom)
            }
        }
        .sheet(isPresented: $showSettings) {
            EchoelSettingsView()
                .environment(themeManager)
                .environment(audioEngine)
        }
    }

    // MARK: - Desktop Layout (iPad)

    private var desktopLayout: some View {
        VStack(spacing: 0) {
            topBar

            HStack(spacing: 0) {
                if sidebarExpanded {
                    sidebar
                        .frame(width: 200)
                        .transition(.move(edge: .leading))
                }

                workspaceContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            transportBar
        }
    }

    // MARK: - Mobile Layout (iPhone)

    private var mobileLayout: some View {
        VStack(spacing: 0) {
            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            transportBar

            mobileTabBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: EchoelSpacing.sm) {
            Button(action: {
                withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85)) {
                    sidebarExpanded.toggle()
                }
            }) {
                Image(systemName: sidebarExpanded ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.xs)
                            .fill(EchoelBrand.bgElevated.opacity(0.5))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("ECHOELMUSIC")
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textPrimary.opacity(0.7))
                .tracking(4)
                .kerning(0.5)

            Spacer()

            HStack(spacing: EchoelSpacing.xxs) {
                ForEach(Tab.allCases) { tab in
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78)) {
                            currentTab = tab
                        }
                    }) {
                        HStack(spacing: EchoelSpacing.xs) {
                            Image(systemName: currentTab == tab ? tab.filledIcon : tab.icon)
                                .font(.system(size: 11, weight: currentTab == tab ? .semibold : .regular))
                            Text(tab.rawValue)
                                .font(EchoelBrandFont.label())
                                .fontWeight(currentTab == tab ? .semibold : .regular)
                        }
                        .foregroundColor(currentTab == tab ? tab.color : EchoelBrand.textSecondary)
                        .padding(.horizontal, EchoelSpacing.sm + EchoelSpacing.xs)
                        .padding(.vertical, EchoelSpacing.xs + EchoelSpacing.xxs)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .fill(currentTab == tab ? tab.color.opacity(0.1) : Color.clear)
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .stroke(
                                        currentTab == tab ? tab.color.opacity(0.18) : Color.clear,
                                        lineWidth: 0.5
                                    )
                            }
                        )
                        .overlay(alignment: .bottom) {
                            if currentTab == tab {
                                Capsule()
                                    .fill(tab.color)
                                    .frame(width: 16, height: 2)
                                    .offset(y: 1)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Settings gear
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.xs)
                            .fill(EchoelBrand.bgElevated.opacity(0.5))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(
            ZStack {
                EchoelBrand.bgSurface.opacity(0.92)
                if #available(iOS 15.0, *) {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.25)
                }
            }
            .overlay(
                Rectangle()
                    .fill(EchoelBrand.border)
                    .frame(height: 0.5),
                alignment: .bottom
            )
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.xxs) {
            ForEach(Tab.allCases) { tab in
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85)) {
                        currentTab = tab
                    }
                }) {
                    HStack(spacing: EchoelSpacing.sm + EchoelSpacing.xxs) {
                        // Active indicator bar on leading edge
                        RoundedRectangle(cornerRadius: 1)
                            .fill(currentTab == tab ? tab.color : Color.clear)
                            .frame(width: 2.5, height: 16)

                        Image(systemName: currentTab == tab ? tab.filledIcon : tab.icon)
                            .font(.system(size: 14, weight: currentTab == tab ? .semibold : .regular))
                            .frame(width: 20)

                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: currentTab == tab ? .semibold : .regular))

                        Spacer()

                        if currentTab == tab {
                            Circle()
                                .fill(tab.color)
                                .frame(width: 4, height: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .foregroundColor(currentTab == tab ? tab.color : EchoelBrand.textSecondary)
                    .padding(.trailing, EchoelSpacing.sm)
                    .padding(.vertical, EchoelSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(currentTab == tab ? tab.color.opacity(0.08) : EchoelBrand.bgElevated.opacity(0.01))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: EchoelRadius.sm))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Version label at sidebar bottom
            Text("v7.0")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary.opacity(0.5))
                .padding(.bottom, EchoelSpacing.sm)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, EchoelSpacing.sm + EchoelSpacing.xs)
        .padding(.horizontal, EchoelSpacing.sm)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [EchoelBrand.border.opacity(0.3), EchoelBrand.border, EchoelBrand.border.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 0.5),
                    alignment: .trailing
                )
        )
    }

    // MARK: - Workspace Content

    @ViewBuilder
    private var workspaceContent: some View {
        Group {
            switch currentTab {
            case .daw:
                DAWArrangementView()
            case .live:
                SessionClipView()
            case .synth:
                EchoelSynthView()
            case .fx:
                EchoelFXView()
            case .video:
                VideoEditorView()
            }
        }
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentTab)
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: 0) {
            // BPM Section
            HStack(spacing: EchoelSpacing.xxs) {
                Text("\(Int(EchoelCreativeWorkspace.shared.globalBPM))")
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .monospacedDigit()
                Text("BPM")
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .padding(.top, 1)
            }

            transportDivider

            // Transport Controls
            HStack(spacing: EchoelSpacing.sm + EchoelSpacing.xxs) {
                Button(action: {
                    let newTime = max(0, recordingEngine.currentTime - 5.0)
                    recordingEngine.seek(to: newTime)
                    HapticHelper.impact(.light)
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    // Toggle workspace playback — syncs ALL engines (audio, video, session, loops)
                    EchoelCreativeWorkspace.shared.togglePlayback()
                    HapticHelper.impact(.medium)
                }) {
                    ZStack {
                        let isPlaying = EchoelCreativeWorkspace.shared.isPlaying
                        // Outer glow ring when playing
                        Circle()
                            .fill(isPlaying ? EchoelBrand.primary.opacity(0.08) : Color.clear)
                            .frame(width: 42, height: 42)

                        Circle()
                            .fill(isPlaying ? EchoelBrand.primary.opacity(0.15) : EchoelBrand.bgElevated)
                            .frame(width: 36, height: 36)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isPlaying ? EchoelBrand.primary : EchoelBrand.textPrimary)
                            .offset(x: isPlaying ? 0 : 1) // Optical center for play triangle
                    }
                    .shadow(
                        color: EchoelCreativeWorkspace.shared.isPlaying ? EchoelBrand.primary.opacity(0.35) : Color.clear,
                        radius: EchoelCreativeWorkspace.shared.isPlaying ? 10 : 0
                    )
                    .shadow(
                        color: EchoelCreativeWorkspace.shared.isPlaying ? EchoelBrand.primary.opacity(0.15) : Color.clear,
                        radius: EchoelCreativeWorkspace.shared.isPlaying ? 20 : 0
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    if EchoelCreativeWorkspace.shared.isPlaying {
                        EchoelCreativeWorkspace.shared.togglePlayback()
                    }
                    audioEngine.stop()
                    HapticHelper.impact(.light)
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    if recordingEngine.isRecording {
                        try? recordingEngine.stopRecording()
                        HapticHelper.notification(.success)
                    } else {
                        try? recordingEngine.startRecording()
                        HapticHelper.impact(.heavy)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(recordingEngine.isRecording ? EchoelBrand.coral : EchoelBrand.coral.opacity(0.4))
                            .frame(width: 12, height: 12)

                        if recordingEngine.isRecording {
                            Circle()
                                .stroke(EchoelBrand.coral.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Time display
            Text(formatTime(recordingEngine.currentTime))
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.textSecondary)
                .monospacedDigit()

            transportDivider

            // Bio-feedback indicator (mic level as proxy when no HealthKit)
            bioFeedbackIndicator

            transportDivider

            // Stereo LED meters
            HStack(spacing: EchoelSpacing.xs) {
                segmentedMeter(level: audioEngine.masterLevel, label: "L")
                segmentedMeter(level: audioEngine.masterLevelR, label: "R")
            }
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm - EchoelSpacing.xxs)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    /// Visual divider between transport bar sections
    private var transportDivider: some View {
        Rectangle()
            .fill(EchoelBrand.border)
            .frame(width: 1, height: 20)
            .padding(.horizontal, EchoelSpacing.sm)
    }

    /// Segmented LED-style level meter (DAW transport style)
    private func segmentedMeter(level: Float, label: String) -> some View {
        HStack(spacing: EchoelSpacing.xxs) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .frame(width: 8)

            HStack(spacing: 1) {
                ForEach(0..<16, id: \.self) { segment in
                    let threshold = Float(segment) / 16.0
                    let isLit = level > threshold
                    let segmentColor: Color = {
                        if segment >= 13 { return EchoelBrand.coral }
                        if segment >= 10 { return EchoelBrand.amber }
                        return EchoelBrand.emerald
                    }()

                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(isLit ? segmentColor : segmentColor.opacity(0.08))
                        .frame(width: 2.5, height: 8)
                        .animation(.linear(duration: isLit ? 0.02 : 0.15), value: isLit)
                }
            }
        }
    }

    /// Bio-feedback indicator — delegates to isolated subview to avoid re-rendering transport bar
    private var bioFeedbackIndicator: some View {
        BioFeedbackIndicatorView(isAudioRunning: audioEngine.isRunning)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, millis)
    }

    // MARK: - Mobile Tab Bar

    private var mobileTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                        currentTab = tab
                    }
                    HapticHelper.impact(.light)
                }) {
                    VStack(spacing: EchoelSpacing.xs) {
                        ZStack {
                            Image(systemName: currentTab == tab ? tab.filledIcon : tab.icon)
                                .font(.system(size: 20, weight: currentTab == tab ? .semibold : .regular))
                                .scaleEffect(currentTab == tab ? 1.1 : 1.0)
                                .shadow(
                                    color: currentTab == tab ? tab.color.opacity(0.4) : Color.clear,
                                    radius: currentTab == tab ? 6 : 0
                                )
                        }
                        .frame(height: 24)

                        Text(tab.rawValue)
                            .font(EchoelBrandFont.label())
                            .fontWeight(currentTab == tab ? .semibold : .regular)
                    }
                    .foregroundColor(currentTab == tab ? tab.color : EchoelBrand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EchoelSpacing.sm + EchoelSpacing.xxs)
                    .overlay(alignment: .top) {
                        // Active tab indicator pill
                        if currentTab == tab {
                            Capsule()
                                .fill(tab.color)
                                .frame(width: 20, height: 2.5)
                                .offset(y: -EchoelSpacing.xxs)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityAddTraits(currentTab == tab ? .isSelected : [])
            }
        }
        .padding(.bottom, EchoelSpacing.xs)
        .background(
            ZStack {
                EchoelBrand.bgSurface.opacity(0.95)
                if #available(iOS 15.0, *) {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.3)
                }
            }
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [EchoelBrand.border.opacity(0.8), EchoelBrand.border.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5),
                alignment: .top
            )
        )
    }
}

// MARK: - Settings View

struct EchoelSettingsView: View {
    @Environment(ThemeManager.self) var themeManager
    @Environment(AudioEngine.self) var audioEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                EchoelBrand.bgDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EchoelSpacing.lg) {

                        // MARK: - Appearance
                        settingsSection(title: "APPEARANCE") {
                            ThemeModePicker(themeManager: themeManager)
                                .padding(.horizontal, EchoelSpacing.md)
                        }

                        // MARK: - Audio
                        settingsSection(title: "AUDIO") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "speaker.wave.2",
                                    label: "Master Volume",
                                    value: "\(Int(audioEngine.masterVolume * 100))%"
                                )

                                Slider(
                                    value: Binding(
                                        get: { Double(audioEngine.masterVolume) },
                                        set: { audioEngine.masterVolume = Float($0) }
                                    ),
                                    in: 0...1
                                )
                                .tint(EchoelBrand.primary)
                                .padding(.horizontal, EchoelSpacing.md)

                                settingsRow(
                                    icon: "waveform",
                                    label: "Audio Engine",
                                    value: audioEngine.isRunning ? "Running" : "Stopped"
                                )

                                settingsRow(
                                    icon: "mic",
                                    label: "Input Monitoring",
                                    value: audioEngine.inputMonitoringEnabled ? "On" : "Off"
                                )
                            }
                        }

                        // MARK: - Sync
                        settingsSection(title: "SYNC") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "link",
                                    label: "Ableton Link",
                                    value: EchoelCreativeWorkspace.shared.linkClient.isEnabled ? "Active" : "Off"
                                )
                                settingsRow(
                                    icon: "antenna.radiowaves.left.and.right",
                                    label: "Link Peers",
                                    value: "\(EchoelCreativeWorkspace.shared.linkClient.peers.count)"
                                )
                            }
                        }

                        // MARK: - Bio-Feedback
                        settingsSection(title: "BIO-FEEDBACK") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "heart.fill",
                                    label: "Bio-Reactive Mode",
                                    value: "Active"
                                )

                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 12))
                                        .foregroundColor(EchoelBrand.amber)
                                    Text("Bio data is for self-observation, not medical diagnosis.")
                                        .font(EchoelBrandFont.caption())
                                        .foregroundColor(EchoelBrand.textSecondary)
                                }
                                .padding(.horizontal, EchoelSpacing.md)
                            }
                        }

                        // MARK: - Safety
                        settingsSection(title: "SAFETY") {
                            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                                safetyWarning("NOT while operating vehicles")
                                safetyWarning("NOT under influence of alcohol/drugs")
                                safetyWarning("Max 3 Hz visual flash rate (WCAG)")
                                safetyWarning("Coordinate therapeutic use with your provider")
                            }
                            .padding(.horizontal, EchoelSpacing.md)
                        }

                        // MARK: - Tuning
                        settingsSection(title: "TUNING") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "tuningfork",
                                    label: "Concert Pitch (A4)",
                                    value: String(format: "%.1f Hz", TuningManager.shared.concertPitch)
                                )
                                KammertonWheelView()
                                    .padding(.horizontal, EchoelSpacing.sm)
                            }
                        }

                        // MARK: - About
                        settingsSection(title: "ABOUT") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(icon: "info.circle", label: "Version", value: "7.0")
                                settingsRow(icon: "hammer", label: "Build", value: "22572541274")
                                settingsRow(icon: "person", label: "Developer", value: "Echoel")
                                settingsRow(icon: "building.2", label: "Studio", value: "Hamburg")

                                Text("Create from Within")
                                    .font(EchoelBrandFont.caption())
                                    .foregroundColor(EchoelBrand.textSecondary)
                                    .italic()
                                    .padding(.top, EchoelSpacing.xs)
                            }
                        }
                    }
                    .padding(.vertical, EchoelSpacing.lg)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EchoelBrand.primary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(2)
                .padding(.horizontal, EchoelSpacing.lg)

            VStack(spacing: EchoelSpacing.xs) {
                content()
            }
            .padding(.vertical, EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(EchoelBrand.bgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.md)
                            .stroke(EchoelBrand.border, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, EchoelSpacing.md)
        }
    }

    private func settingsRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(EchoelBrand.primary)
                .frame(width: 24)

            Text(label)
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.textPrimary)

            Spacer()

            Text(value)
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, EchoelSpacing.md)
    }

    private func safetyWarning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: EchoelSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(EchoelBrand.amber)
                .padding(.top, 2)

            Text(text)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)
        }
    }
}

// MARK: - Isolated Bio Feedback Indicator

/// Isolated view that only re-renders when bioCoherence or audio running state changes.
/// Prevents 60Hz+ coherence updates from triggering full transport bar re-render.
private struct BioFeedbackIndicatorView: View {
    let isAudioRunning: Bool
    private let workspace = EchoelCreativeWorkspace.shared

    var body: some View {
        HStack(spacing: EchoelSpacing.xs) {
            let level = CGFloat(workspace.bioCoherence)
            let coherenceColor: Color = level > 0.6 ? EchoelBrand.coherenceHigh
                : level > 0.3 ? EchoelBrand.coherenceMedium
                : EchoelBrand.coherenceLow

            ZStack {
                Circle()
                    .stroke(coherenceColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 18, height: 18)

                Circle()
                    .trim(from: 0, to: max(0.05, level))
                    .stroke(coherenceColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(coherenceColor)
                    .frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("BIO")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textSecondary)
                Text(isAudioRunning ? "LIVE" : "OFF")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(isAudioRunning ? EchoelBrand.emerald : EchoelBrand.textDisabled)
            }
        }
    }
}
#endif
