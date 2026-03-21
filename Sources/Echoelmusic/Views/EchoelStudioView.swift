#if canImport(SwiftUI)
import SwiftUI

// MARK: - Panel Context Environment Key

/// Tells embedded views they're inside a bottom panel (skip their own headers)
private struct IsEmbeddedInPanelKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isEmbeddedInPanel: Bool {
        get { self[IsEmbeddedInPanelKey.self] }
        set { self[IsEmbeddedInPanelKey.self] = newValue }
    }
}

// MARK: - Echoelmusic Workspace View
// Unified creative workspace: audio + video on one BPM-synchronized timeline
// Bottom panel drawers for instruments, mixer, FX, and video preview
//
// Panel Architecture: 5 tabs, each with sub-tools accessible via segmented picker
//   Create  → Instruments, Sequencer, Piano Roll
//   Mix     → Mixer, FX
//   Bio     → Bio status
//   Media   → Visuals, Video, Lighting, Stage
//   Connect → Network, AI

struct EchoelStudioView: View {
    @Environment(AudioEngine.self) var audioEngine
    @Environment(RecordingEngine.self) var recordingEngine

    @State private var viewMode: ViewMode = .session
    @State private var activeTab: ToolTab? = .create
    @State private var createSubtab: CreateSubtab = .instruments
    @State private var mixSubtab: MixSubtab = .mixer
    @State private var mediaSubtab: MediaSubtab = .visuals
    @State private var connectSubtab: ConnectSubtab = .network
    @State private var selectedTrackID: UUID?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    // MARK: - View Mode

    enum ViewMode: String, CaseIterable {
        case arrangement = "Arrangement"
        case session = "Session"

        var icon: String {
            switch self {
            case .arrangement: return "waveform"
            case .session: return "square.grid.3x3"
            }
        }
    }

    // MARK: - Tool Tabs (5 categories)

    enum ToolTab: String, CaseIterable, Identifiable {
        case create = "Create"
        case mix = "Mix"
        case bio = "Bio"
        case media = "Media"
        case connect = "Connect"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .create: return "pianokeys"
            case .mix: return "slider.vertical.3"
            case .bio: return "heart.fill"
            case .media: return "eye"
            case .connect: return "network"
            }
        }

        var color: Color {
            switch self {
            case .create: return EchoelBrand.sky
            case .mix: return EchoelBrand.emerald
            case .bio: return EchoelBrand.coral
            case .media: return EchoelBrand.violet
            case .connect: return EchoelBrand.amber
            }
        }
    }

    // MARK: - Subtabs

    enum CreateSubtab: String, CaseIterable { case instruments = "Instruments", sequencer = "Sequencer", pianoRoll = "Piano Roll" }
    enum MixSubtab: String, CaseIterable { case mixer = "Mixer", fx = "FX" }
    enum MediaSubtab: String, CaseIterable { case visuals = "Visuals", video = "Video", lighting = "Lighting", stage = "Stage" }
    enum ConnectSubtab: String, CaseIterable { case network = "Network", ai = "AI" }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let panelHeight = isCompact ? min(geo.size.height * 0.42, 320) : 320

            VStack(spacing: 0) {
                // Main content area
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom panel (collapsible)
                if let tab = activeTab {
                    bottomPanelView(tab, height: panelHeight)
                }

                // Bottom tab bar — 5 clear categories
                bottomTabBar
            }
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
        .onAppear {
            ensureSessionExists()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch viewMode {
        case .arrangement:
            DAWArrangementView()
                .environment(audioEngine)
                .environment(recordingEngine)
        case .session:
            SessionClipView()
                .environment(audioEngine)
                .environment(recordingEngine)
        }
    }

    // MARK: - Bottom Panel Content

    @ViewBuilder
    private func bottomPanelView(_ tab: ToolTab, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Panel header with subtab picker
            panelHeader(tab)

            // Panel content
            ScrollView {
                Group {
                    switch tab {
                    case .create:
                        switch createSubtab {
                        case .instruments:
                            EchoelSynthView()
                                .environment(audioEngine)
                        case .sequencer:
                            VisualStepSequencerView()
                        case .pianoRoll:
                            PianoRollView()
                        }
                    case .mix:
                        switch mixSubtab {
                        case .mixer:
                            RealMixerSheet()
                                .environment(audioEngine)
                                .environment(recordingEngine)
                        case .fx:
                            EchoelFXView()
                                .environment(audioEngine)
                        }
                    case .bio:
                        BioStatusView()
                    case .media:
                        switch mediaSubtab {
                        case .visuals:
                            EchoelVisView()
                        case .video:
                            VideoEditorView()
                        case .lighting:
                            EchoelLuxView()
                        case .stage:
                            EchoelStageView()
                        }
                    case .connect:
                        switch connectSubtab {
                        case .network:
                            EchoelNetView()
                        case .ai:
                            EchoelAIView()
                        }
                    }
                }
                .environment(\.isEmbeddedInPanel, true)
                .frame(maxWidth: .infinity)
            }
            .frame(height: height)
        }
        .background(EchoelBrand.bgSurface)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Panel Header (title + subtab picker + close)

    private func panelHeader(_ tab: ToolTab) -> some View {
        HStack(spacing: EchoelSpacing.sm) {
            // Tab icon + title
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tab.color)

            // Subtab picker (inline segmented control)
            subtabPicker(for: tab)

            Spacer()

            // Close button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeTab = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().fill(EchoelBrand.bgElevated)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 0.5),
                    alignment: .top
                )
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }

    @ViewBuilder
    private func subtabPicker(for tab: ToolTab) -> some View {
        switch tab {
        case .create:
            segmentedPicker(CreateSubtab.allCases, selection: $createSubtab, color: tab.color) { $0.rawValue }
        case .mix:
            segmentedPicker(MixSubtab.allCases, selection: $mixSubtab, color: tab.color) { $0.rawValue }
        case .bio:
            Text("BIO")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(1.5)
        case .media:
            segmentedPicker(MediaSubtab.allCases, selection: $mediaSubtab, color: tab.color) { $0.rawValue }
        case .connect:
            segmentedPicker(ConnectSubtab.allCases, selection: $connectSubtab, color: tab.color) { $0.rawValue }
        }
    }

    /// Compact segmented picker for subtabs
    private func segmentedPicker<T: Hashable>(_ items: [T], selection: Binding<T>, color: Color, label: @escaping (T) -> String) -> some View {
        HStack(spacing: 2) {
            ForEach(items, id: \T.self) { item in
                let isActive = selection.wrappedValue == item
                Button {
                    selection.wrappedValue = item
                    HapticHelper.impact(.light)
                } label: {
                    Text(label(item))
                        .font(.system(size: 10, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? color : EchoelBrand.textSecondary)
                        .padding(.horizontal, EchoelSpacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isActive ? color.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bottom Tab Bar (5 tabs)

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            // View mode toggle (Arrangement / Session)
            viewModeToggle

            // Divider
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(width: 1, height: 28)
                .padding(.horizontal, EchoelSpacing.sm)

            // 5 tool tabs — no scrolling needed
            HStack(spacing: 0) {
                ForEach(ToolTab.allCases) { tab in
                    Button {
                        echoelWithAnimation(.easeInOut(duration: 0.2)) {
                            if activeTab == tab {
                                activeTab = nil
                            } else {
                                activeTab = tab
                            }
                        }
                        HapticHelper.impact(.light)
                    } label: {
                        let isActive = activeTab == tab
                        VStack(spacing: EchoelSpacing.xxs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: isCompact ? 16 : 14, weight: isActive ? .semibold : .regular))
                                .symbolRenderingMode(.hierarchical)

                            Text(tab.rawValue)
                                .font(.system(size: isCompact ? 9 : 10, weight: isActive ? .bold : .medium))
                        }
                        .foregroundColor(isActive ? tab.color : EchoelBrand.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? EchoelSpacing.sm : EchoelSpacing.sm + EchoelSpacing.xxs)
                        .background(
                            isActive ? tab.color.opacity(0.08) : Color.clear
                        )
                        .overlay(alignment: .top) {
                            if isActive {
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .fill(tab.color)
                                    .frame(width: 20, height: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tab.rawValue) panel")
                    .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
                }
            }
        }
        .background(
            ZStack {
                EchoelBrand.bgSurface.opacity(0.95)
                Rectangle().fill(EchoelBrand.bgElevated.opacity(0.15))
            }
            .overlay(
                Rectangle()
                    .fill(EchoelBrand.border)
                    .frame(height: 0.5),
                alignment: .top
            )
        )
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = mode
                    }
                    HapticHelper.impact(.light)
                } label: {
                    let isActive = viewMode == mode
                    HStack(spacing: EchoelSpacing.xs) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        if !isCompact {
                            Text(mode.rawValue)
                                .font(EchoelBrandFont.label())
                                .fontWeight(isActive ? .semibold : .regular)
                        }
                    }
                    .foregroundColor(isActive ? EchoelBrand.primary : EchoelBrand.textSecondary)
                    .padding(.horizontal, EchoelSpacing.sm)
                    .padding(.vertical, EchoelSpacing.xs + 2)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(isActive ? EchoelBrand.primary.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.rawValue) mode")
                .accessibilityAddTraits(viewMode == mode ? .isSelected : [])
            }
        }
        .padding(.horizontal, EchoelSpacing.sm)
    }

    // MARK: - Helpers

    private func ensureSessionExists() {
        if recordingEngine.currentSession == nil {
            _ = recordingEngine.createSession(name: "New Project", template: .custom)
        }
    }
}
#endif
