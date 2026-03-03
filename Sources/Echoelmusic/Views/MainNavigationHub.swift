import SwiftUI

/// Main navigation — DAW + Video workspaces
struct MainNavigationHub: View {

    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var recordingEngine: RecordingEngine

    @State private var currentTab: Tab = .daw
    @State private var sidebarExpanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Tab: String, CaseIterable, Identifiable {
        case daw = "DAW"
        case video = "Video"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .daw: return "pianokeys"
            case .video: return "film"
            }
        }

        var filledIcon: String {
            switch self {
            case .daw: return "pianokeys.inverse"
            case .video: return "film.fill"
            }
        }

        var color: Color {
            switch self {
            case .daw: return EchoelBrand.sky
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
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    sidebarExpanded.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text("ECHOELMUSIC")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(EchoelBrand.textPrimary)
                    .tracking(2)
            }

            Spacer()

            ForEach(Tab.allCases) { tab in
                Button(action: { currentTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: currentTab == tab ? tab.filledIcon : tab.icon)
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(currentTab == tab ? tab.color : EchoelBrand.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        currentTab == tab
                            ? tab.color.opacity(0.15)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Tab.allCases) { tab in
                Button(action: { currentTab = tab }) {
                    HStack(spacing: 10) {
                        Image(systemName: currentTab == tab ? tab.filledIcon : tab.icon)
                            .font(.system(size: 16))
                            .frame(width: 24)

                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: currentTab == tab ? .semibold : .regular))

                        Spacer()
                    }
                    .foregroundColor(currentTab == tab ? tab.color : EchoelBrand.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        currentTab == tab
                            ? tab.color.opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .background(EchoelBrand.bgSurface)
    }

    // MARK: - Workspace Content

    @ViewBuilder
    private var workspaceContent: some View {
        switch currentTab {
        case .daw:
            DAWArrangementView()
        case .video:
            VideoEditorView()
        }
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: 16) {
            // BPM
            Text("\(Int(EchoelCreativeWorkspace.shared.globalBPM)) BPM")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)

            Spacer()

            // Transport Controls
            Button(action: {}) {
                Image(systemName: "backward.fill")
                    .foregroundColor(EchoelBrand.textPrimary)
            }
            .buttonStyle(.plain)

            Button(action: {
                if audioEngine.isRunning {
                    audioEngine.stop()
                } else {
                    audioEngine.start()
                }
            }) {
                Image(systemName: audioEngine.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(EchoelBrand.primary)
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                Image(systemName: "stop.fill")
                    .foregroundColor(EchoelBrand.textPrimary)
            }
            .buttonStyle(.plain)

            Button(action: {
                recordingEngine.toggleRecording()
            }) {
                Circle()
                    .fill(recordingEngine.isRecording ? Color.red : Color.red.opacity(0.6))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)

            Spacer()

            // Time display
            Text("00:00:00")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    // MARK: - Mobile Tab Bar

    private var mobileTabBar: some View {
        HStack {
            ForEach(Tab.allCases) { tab in
                Spacer()
                Button(action: { currentTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: currentTab == tab ? tab.filledIcon : tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(currentTab == tab ? tab.color : EchoelBrand.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .background(EchoelBrand.bgSurface)
    }
}
