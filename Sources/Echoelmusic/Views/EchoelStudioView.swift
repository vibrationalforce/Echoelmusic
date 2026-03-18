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

struct EchoelStudioView: View {
    @Environment(AudioEngine.self) var audioEngine
    @Environment(RecordingEngine.self) var recordingEngine

    @State private var viewMode: ViewMode = .arrangement
    @State private var bottomPanel: BottomPanel?
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

    // MARK: - Bottom Panel

    enum BottomPanel: String, CaseIterable, Identifiable {
        case instruments = "Instruments"
        case sequencer = "Sequencer"
        case pianoRoll = "Piano Roll"
        case mixer = "Mixer"
        case fx = "FX"
        case bio = "Bio"
        case visuals = "Visuals"
        case video = "Video"
        case lighting = "Lighting"
        case stage = "Stage"
        case ai = "AI"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .instruments: return "pianokeys"
            case .sequencer: return "square.grid.3x3"
            case .pianoRoll: return "music.note.list"
            case .mixer: return "slider.vertical.3"
            case .fx: return "waveform.path.ecg"
            case .bio: return "heart.fill"
            case .visuals: return "eye"
            case .video: return "film"
            case .lighting: return "light.max"
            case .stage: return "display"
            case .ai: return "cpu"
            }
        }

        var color: Color {
            switch self {
            case .instruments: return EchoelBrand.sky
            case .sequencer: return EchoelBrand.amber
            case .pianoRoll: return Color(red: 1, green: 0.8, blue: 0.2)
            case .mixer: return EchoelBrand.emerald
            case .fx: return EchoelBrand.violet
            case .bio: return EchoelBrand.coral
            case .visuals: return Color(red: 0.6, green: 0.4, blue: 1.0)
            case .video: return EchoelBrand.rose
            case .lighting: return Color(red: 1, green: 0.8, blue: 0.4)
            case .stage: return Color(red: 0.4, green: 0.8, blue: 1.0)
            case .ai: return EchoelBrand.sky
            }
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let panelHeight = isCompact ? min(geo.size.height * 0.42, 320) : 320

            VStack(spacing: 0) {
                // Main content area
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom panel (collapsible)
                if let panel = bottomPanel {
                    bottomPanelView(panel, height: panelHeight)
                }

                // Bottom panel tab bar
                bottomPanelTabBar
            }
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
        .echoelWaveBackground(lineCount: 3, animated: false)
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
    private func bottomPanelView(_ panel: BottomPanel, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            panelDragHandle(panel)

            // Panel content in ScrollView for overflow handling
            ScrollView {
                Group {
                    switch panel {
                    case .instruments:
                        EchoelSynthView()
                            .environment(audioEngine)
                    case .sequencer:
                        VisualStepSequencerView()
                    case .pianoRoll:
                        PianoRollView()
                    case .mixer:
                        RealMixerSheet()
                            .environment(audioEngine)
                            .environment(recordingEngine)
                    case .fx:
                        EchoelFXView()
                            .environment(audioEngine)
                    case .bio:
                        BioStatusView()
                    case .visuals:
                        EchoelVisView()
                    case .video:
                        VideoEditorView()
                    case .lighting:
                        EchoelLuxView()
                    case .stage:
                        EchoelStageView()
                    case .ai:
                        EchoelAIView()
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

    private func panelDragHandle(_ panel: BottomPanel) -> some View {
        HStack {
            // Panel title
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: panel.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(panel.color)
                Text(panel.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(1.5)
            }

            Spacer()

            // Close button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    bottomPanel = nil
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

    // MARK: - Bottom Panel Tab Bar

    private var bottomPanelTabBar: some View {
        HStack(spacing: 0) {
            // View mode toggle (Arrangement / Session)
            viewModeToggle

            // Divider
            Rectangle()
                .fill(EchoelBrand.border)
                .frame(width: 1, height: 28)
                .padding(.horizontal, EchoelSpacing.sm)

            // Panel tabs — scrollable for all 9 tools
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
            ForEach(BottomPanel.allCases) { panel in
                Button {
                    echoelWithAnimation(.easeInOut(duration: 0.2)) {
                        if bottomPanel == panel {
                            bottomPanel = nil
                        } else {
                            bottomPanel = panel
                        }
                    }
                    HapticHelper.impact(.light)
                } label: {
                    let isActive = bottomPanel == panel
                    VStack(spacing: EchoelSpacing.xxs) {
                        Image(systemName: panel.icon)
                            .font(.system(size: isCompact ? 16 : 14, weight: isActive ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)

                        if !isCompact {
                            Text(panel.rawValue)
                                .font(EchoelBrandFont.label())
                        }
                    }
                    .foregroundColor(isActive ? panel.color : EchoelBrand.textSecondary)
                    .frame(width: isCompact ? 52 : 72)
                    .padding(.vertical, isCompact ? EchoelSpacing.sm : EchoelSpacing.sm + EchoelSpacing.xxs)
                    .background(
                        isActive ? panel.color.opacity(0.08) : Color.clear
                    )
                    .overlay(alignment: .top) {
                        if isActive {
                            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                .fill(panel.color)
                                .frame(width: 20, height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(panel.rawValue) panel")
                .accessibilityAddTraits(bottomPanel == panel ? .isSelected : [])
            }
            } // HStack (scrollable panels)
            } // ScrollView
        }
        .background(
            ZStack {
                EchoelBrand.bgSurface.opacity(0.95)
                // Solid surface — no glassmorphism
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
