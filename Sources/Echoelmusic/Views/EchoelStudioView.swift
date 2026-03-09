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

// MARK: - EchoelStudio View
// Unified creative workspace: audio + video on one BPM-synchronized timeline
// Bottom panel drawers for instruments, mixer, FX, and video preview

struct EchoelStudioView: View {
    @Environment(AudioEngine.self) var audioEngine
    @Environment(RecordingEngine.self) var recordingEngine
    @Bindable private var workspace = EchoelCreativeWorkspace.shared

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
        case pianoRoll = "Piano Roll"
        case mixer = "Mixer"
        case fx = "FX"
        case video = "Video"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .instruments: return "pianokeys"
            case .pianoRoll: return "music.note.list"
            case .mixer: return "slider.vertical.3"
            case .fx: return "waveform.path.ecg"
            case .video: return "film"
            }
        }

        var color: Color {
            switch self {
            case .instruments: return EchoelBrand.sky
            case .pianoRoll: return Color(red: 1, green: 0.8, blue: 0.2)
            case .mixer: return EchoelBrand.emerald
            case .fx: return EchoelBrand.violet
            case .video: return EchoelBrand.coral
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
                    case .pianoRoll:
                        PianoRollView()
                    case .mixer:
                        RealMixerSheet()
                            .environment(audioEngine)
                            .environment(recordingEngine)
                    case .fx:
                        EchoelFXView()
                            .environment(audioEngine)
                    case .video:
                        VideoEditorView()
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

            // Panel tabs
            ForEach(BottomPanel.allCases) { panel in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? EchoelSpacing.sm : EchoelSpacing.sm + EchoelSpacing.xxs)
                    .background(
                        isActive ? panel.color.opacity(0.08) : Color.clear
                    )
                    .overlay(alignment: .top) {
                        if isActive {
                            Capsule()
                                .fill(panel.color)
                                .frame(width: 20, height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(panel.rawValue) panel")
                .accessibilityAddTraits(bottomPanel == panel ? .isSelected : [])
            }
        }
        .background(
            ZStack {
                EchoelBrand.bgSurface.opacity(0.95)
                if #available(iOS 15.0, *) {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.3)
                }
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
