import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELVIEW - ONE VIEW TO RULE THEM ALL
// ═══════════════════════════════════════════════════════════════════════════════
//
// Adaptive unified view that shows the right panels for the current engine mode.
// Replaces 82 scattered views with ONE context-aware interface.
//
// Layout:
// ┌──────────────────────────────────────────────────────────────┐
// │ Mode Bar: [Studio] [Live] [Video] [Meditation] [DJ] ...     │
// ├──────────────┬───────────────────────────┬───────────────────┤
// │  Left Panel  │                           │   Right Panel     │
// │  (Browser/   │      Main Canvas          │   (Inspector/     │
// │   Tracks)    │   (Visual + Transport)    │    Bio + FX)      │
// ├──────────────┴───────────────────────────┴───────────────────┤
// │ Bottom Panel: Transport / Mixer / Timeline                    │
// └──────────────────────────────────────────────────────────────┘
//
// Platforms: iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - EchoelView

public struct EchoelView: View {
    @StateObject private var engine = EchoelEngine.shared

    @State private var showLeftPanel = true
    @State private var showRightPanel = true
    @State private var bottomPanelHeight: CGFloat = 200
    @State private var selectedLeftTab: LeftTab = .browser
    @State private var selectedRightTab: RightTab = .bio
    @State private var isFullscreen = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Mode bar
            modeBar

            // Main content
            GeometryReader { geo in
                adaptiveLayout(size: geo.size)
            }

            // Bottom panel
            if !isFullscreen {
                bottomPanel
                    .frame(height: bottomPanelHeight)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            engine.start(mode: engine.mode)
        }
        .onDisappear {
            engine.stop()
        }
        #if canImport(UIKit)
        .statusBarHidden(isFullscreen)
        #endif
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EngineMode.allCases) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: engine.mode == mode,
                        action: { engine.mode = mode }
                    )
                }

                Spacer()

                // Performance indicator
                performanceIndicator

                // Fullscreen toggle
                Button(action: { isFullscreen.toggle() }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Adaptive Layout

    @ViewBuilder
    private func adaptiveLayout(size: CGSize) -> some View {
        let isCompact = size.width < 600

        if isCompact {
            // iPhone: Tab-based navigation
            compactLayout
        } else {
            // iPad/Mac: Panel-based layout
            regularLayout(size: size)
        }
    }

    private var compactLayout: some View {
        TabView {
            mainCanvas
                .tabItem { Label("Canvas", systemImage: "paintpalette") }

            leftPanelContent
                .tabItem { Label("Browser", systemImage: "folder") }

            rightPanelContent
                .tabItem { Label("Inspector", systemImage: "slider.horizontal.3") }
        }
    }

    private func regularLayout(size: CGSize) -> some View {
        HStack(spacing: 0) {
            // Left panel
            if showLeftPanel {
                leftPanel
                    .frame(width: 250)
                    .transition(.move(edge: .leading))
            }

            // Main canvas
            mainCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right panel
            if showRightPanel {
                rightPanel
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - Main Canvas

    private var mainCanvas: some View {
        ZStack {
            // Background visualization
            visualizationLayer

            // Mode-specific overlay
            modeOverlay

            // Transport overlay (always visible)
            VStack {
                Spacer()
                transportBar
                    .padding(.bottom, 8)
            }

            // Panel toggles
            panelToggles
        }
        .clipped()
    }

    @ViewBuilder
    private var visualizationLayer: some View {
        switch engine.mode {
        case .studio, .live, .dj:
            AudioVisualizerCanvas(
                audioLevel: engine.state.audioLevel,
                coherence: engine.state.coherence,
                bpm: engine.state.bpm
            )
        case .meditation:
            MeditationCanvas(
                coherence: engine.state.coherence,
                breathPhase: engine.state.breathPhase,
                heartRate: engine.state.heartRate
            )
        case .video:
            VideoPreviewCanvas()
        case .collaboration:
            CollaborationCanvas(coherence: engine.state.coherence)
        case .immersive:
            ImmersivePreviewCanvas(coherence: engine.state.coherence)
        case .research:
            ResearchDashboardCanvas(state: engine.state)
        }
    }

    @ViewBuilder
    private var modeOverlay: some View {
        switch engine.mode {
        case .studio:
            StudioOverlay(engine: engine)
        case .live:
            LiveOverlay(engine: engine)
        case .meditation:
            MeditationOverlay(engine: engine)
        case .video:
            VideoOverlay(engine: engine)
        case .dj:
            DJOverlay(engine: engine)
        default:
            EmptyView()
        }
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: 16) {
            // Rewind
            Button(action: { engine.stopPlayback() }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
            }

            // Play/Pause
            Button(action: {
                if engine.state.isPlaying { engine.pause() } else { engine.play() }
            }) {
                Image(systemName: engine.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(engine.state.isPlaying ? Color.orange : Color.green)
                    .clipShape(Circle())
            }

            // BPM display
            Text("\(Int(engine.state.bpm)) BPM")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Bio indicators
            if engine.activeSubsystems.contains(.bio) {
                bioMiniDisplay
            }

            // Position
            Text(formatTime(engine.state.position))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private var bioMiniDisplay: some View {
        HStack(spacing: 8) {
            // Heart rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                Text("\(Int(engine.state.heartRate))")
                    .font(.system(size: 12, design: .monospaced))
            }

            // Coherence
            HStack(spacing: 4) {
                Circle()
                    .fill(coherenceColor(engine.state.coherence))
                    .frame(width: 8, height: 8)
                Text("\(Int(engine.state.coherence * 100))%")
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .foregroundColor(.white.opacity(0.7))
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(LeftTab.allCases, id: \.self) { tab in
                    Button(action: { selectedLeftTab = tab }) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedLeftTab == tab ? Color.white.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedLeftTab == tab ? .white : .white.opacity(0.5))
                }
            }
            .background(Color.black.opacity(0.5))

            leftPanelContent
        }
        .background(Color.black.opacity(0.85))
    }

    @ViewBuilder
    private var leftPanelContent: some View {
        switch selectedLeftTab {
        case .browser:
            BrowserPanel(mode: engine.mode)
        case .tracks:
            TracksPanel(engine: engine)
        case .scenes:
            ScenesPanel(engine: engine)
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(rightTabsForMode, id: \.self) { tab in
                    Button(action: { selectedRightTab = tab }) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedRightTab == tab ? Color.white.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedRightTab == tab ? .white : .white.opacity(0.5))
                }
            }
            .background(Color.black.opacity(0.5))

            rightPanelContent
        }
        .background(Color.black.opacity(0.85))
    }

    @ViewBuilder
    private var rightPanelContent: some View {
        switch selectedRightTab {
        case .bio:
            BioInspectorPanel(state: engine.state)
        case .fx:
            FXInspectorPanel(engine: engine)
        case .visual:
            VisualInspectorPanel(engine: engine)
        case .settings:
            SettingsPanel(engine: engine)
        }
    }

    private var rightTabsForMode: [RightTab] {
        switch engine.mode {
        case .meditation:
            return [.bio, .visual, .settings]
        case .video:
            return [.fx, .visual, .settings]
        default:
            return RightTab.allCases
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        Group {
            switch engine.mode {
            case .studio:
                MixerStrip(engine: engine)
            case .live, .dj:
                PerformanceStrip(engine: engine)
            case .video:
                TimelineStrip(engine: engine)
            case .meditation:
                BreathingGuideStrip(state: engine.state)
            case .collaboration:
                CollaborationStrip(engine: engine)
            default:
                MixerStrip(engine: engine)
            }
        }
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Panel Toggles

    private var panelToggles: some View {
        VStack {
            HStack {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showLeftPanel.toggle() } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(showLeftPanel ? 0.8 : 0.3))
                        .padding(8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showRightPanel.toggle() } }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(showRightPanel ? 0.8 : 0.3))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Performance Indicator

    private var performanceIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(fpsColor)
                .frame(width: 6, height: 6)
            Text("\(Int(engine.state.fps)) FPS")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var fpsColor: Color {
        let fps = engine.state.fps
        if fps >= 55 { return .green }
        if fps >= 30 { return .yellow }
        return .red
    }

    // MARK: - Helpers

    private func coherenceColor(_ c: Float) -> Color {
        if c > 0.7 { return .green }
        if c > 0.4 { return .yellow }
        return .red
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }
}

// MARK: - Tab Types

enum LeftTab: String, CaseIterable {
    case browser, tracks, scenes

    var icon: String {
        switch self {
        case .browser: return "folder"
        case .tracks: return "list.bullet"
        case .scenes: return "square.grid.2x2"
        }
    }
}

enum RightTab: String, CaseIterable {
    case bio, fx, visual, settings

    var icon: String {
        switch self {
        case .bio: return "heart.fill"
        case .fx: return "wand.and.stars"
        case .visual: return "paintpalette"
        case .settings: return "gear"
        }
    }
}

// MARK: - Mode Button

private struct ModeButton: View {
    let mode: EngineMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 12))
                Text(mode.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
    }
}

// MARK: - Canvas Views (mode-specific rendering)

struct AudioVisualizerCanvas: View {
    let audioLevel: Float
    let coherence: Float
    let bpm: Double

    var body: some View {
        Canvas { context, size in
            // Waveform bars
            let barCount = 64
            let barWidth = size.width / CGFloat(barCount)
            for i in 0..<barCount {
                let x = CGFloat(i) * barWidth
                let phase = Double(i) / Double(barCount) * .pi * 4
                let amplitude = CGFloat(audioLevel) * sin(phase) * 0.5 + 0.5
                let height = amplitude * size.height * 0.6
                let y = (size.height - height) / 2

                let hue = Double(coherence) * 0.3 + Double(i) / Double(barCount) * 0.2
                let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

                context.fill(
                    Path(CGRect(x: x + 1, y: y, width: barWidth - 2, height: height)),
                    with: .color(color.opacity(0.8))
                )
            }
        }
        .accessibilityLabel("Audio visualizer showing \(Int(bpm)) BPM")
    }
}

struct MeditationCanvas: View {
    let coherence: Float
    let breathPhase: Float
    let heartRate: Double

    var body: some View {
        ZStack {
            // Breathing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(Double(coherence) * 0.5),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 200 + CGFloat(breathPhase) * 50
                    )
                )
                .frame(width: 300 + CGFloat(breathPhase) * 60,
                       height: 300 + CGFloat(breathPhase) * 60)
                .animation(.easeInOut(duration: 2), value: breathPhase)

            // Coherence text
            VStack(spacing: 8) {
                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.white)
                Text("Coherence")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .accessibilityLabel("Meditation view. Coherence \(Int(coherence * 100)) percent. Heart rate \(Int(heartRate))")
    }
}

struct VideoPreviewCanvas: View {
    var body: some View {
        ZStack {
            Color.black
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))
            Text("Video Preview")
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct CollaborationCanvas: View {
    let coherence: Float

    var body: some View {
        ZStack {
            Color.black
            Circle()
                .stroke(Color.cyan.opacity(Double(coherence)), lineWidth: 2)
                .frame(width: 200, height: 200)
            Text("Group Session")
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct ImmersivePreviewCanvas: View {
    let coherence: Float

    var body: some View {
        ZStack {
            Color.black
            Image(systemName: "visionpro")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

struct ResearchDashboardCanvas: View {
    let state: EngineState

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                MetricCard(title: "Heart Rate", value: "\(Int(state.heartRate))", unit: "BPM", color: .red)
                MetricCard(title: "HRV", value: "\(Int(state.hrv))", unit: "ms", color: .blue)
                MetricCard(title: "Coherence", value: "\(Int(state.coherence * 100))", unit: "%", color: .green)
            }
            HStack(spacing: 24) {
                MetricCard(title: "Breath Rate", value: "\(Int(state.breathingRate))", unit: "/min", color: .cyan)
                MetricCard(title: "CPU", value: "\(Int(state.cpuUsage))", unit: "%", color: .orange)
                MetricCard(title: "FPS", value: "\(Int(state.fps))", unit: "", color: .yellow)
            }
        }
        .padding()
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(minWidth: 80)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Mode Overlays

struct StudioOverlay: View {
    @ObservedObject var engine: EchoelEngine
    var body: some View { EmptyView() }
}

struct LiveOverlay: View {
    @ObservedObject var engine: EchoelEngine
    var body: some View { EmptyView() }
}

struct MeditationOverlay: View {
    @ObservedObject var engine: EchoelEngine
    var body: some View { EmptyView() }
}

struct VideoOverlay: View {
    @ObservedObject var engine: EchoelEngine
    var body: some View { EmptyView() }
}

struct DJOverlay: View {
    @ObservedObject var engine: EchoelEngine
    var body: some View { EmptyView() }
}

// MARK: - Panel Content Views

struct BrowserPanel: View {
    let mode: EngineMode

    var body: some View {
        List {
            Section("Presets") {
                ForEach(presetsForMode, id: \.self) { preset in
                    Text(preset)
                        .font(.system(size: 13))
                }
            }
            Section("Files") {
                Text("Recent Projects")
                    .font(.system(size: 13))
            }
        }
        .listStyle(.plain)
    }

    private var presetsForMode: [String] {
        switch mode {
        case .studio: return ["Default Studio", "Vocal Session", "Beat Making", "Mixing"]
        case .live: return ["Concert", "DJ Set", "Acoustic", "Electronic"]
        case .meditation: return ["Deep Calm", "Focus Flow", "Heart Coherence", "Sleep"]
        case .video: return ["Cinematic 4K", "Social Media", "Music Video", "Vlog"]
        case .dj: return ["Techno", "House", "Drum & Bass", "Ambient"]
        default: return ["Default"]
        }
    }
}

struct TracksPanel: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tracks")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Text("No tracks yet")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 12)

            Spacer()
        }
    }
}

struct ScenesPanel: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scenes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Spacer()
        }
    }
}

struct BioInspectorPanel: View {
    let state: EngineState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection(title: "Biometrics") {
                    InspectorRow(label: "Heart Rate", value: "\(Int(state.heartRate)) BPM")
                    InspectorRow(label: "HRV", value: "\(Int(state.hrv)) ms")
                    InspectorRow(label: "Coherence", value: "\(Int(state.coherence * 100))%")
                    InspectorRow(label: "Breath Rate", value: "\(Int(state.breathingRate))/min")
                }

                InspectorSection(title: "System") {
                    InspectorRow(label: "FPS", value: "\(Int(state.fps))")
                    InspectorRow(label: "CPU", value: "\(Int(state.cpuUsage))%")
                    InspectorRow(label: "Memory", value: "\(Int(state.memoryUsageMB)) MB")
                    InspectorRow(label: "Thermal", value: thermalLabel)
                }
            }
            .padding(12)
        }
    }

    private var thermalLabel: String {
        switch state.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        }
    }
}

struct FXInspectorPanel: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Effects")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Drag effects here")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(12)
        }
    }
}

struct VisualInspectorPanel: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Visuals")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                InspectorRow(label: "Intensity", value: "\(Int(engine.state.visualIntensity * 100))%")
            }
            .padding(12)
        }
    }
}

struct SettingsPanel: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                InspectorRow(label: "Profile", value: engine.performanceProfile.rawValue)
            }
            .padding(12)
        }
    }
}

// MARK: - Bottom Panels

struct MixerStrip: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { i in
                VStack(spacing: 4) {
                    // Level meter
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 20, height: CGFloat.random(in: 20...80))

                    Text("Ch \(i + 1)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
    }
}

struct PerformanceStrip: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        HStack {
            Text("BPM: \(Int(engine.state.bpm))")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
            Spacer()
            Text("LIVE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(16)
    }
}

struct TimelineStrip: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Timeline background
                Rectangle()
                    .fill(Color.white.opacity(0.05))

                // Playhead
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: CGFloat(engine.state.position.truncatingRemainder(dividingBy: 60)) / 60 * geo.size.width)
            }
        }
        .padding(8)
    }
}

struct BreathingGuideStrip: View {
    let state: EngineState

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("BREATHE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                Text(state.breathPhase > 0.5 ? "IN" : "OUT")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundColor(.white)
            }

            // Breathing bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cyan.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(state.breathPhase))
                        .animation(.easeInOut(duration: 1), value: state.breathPhase)
                }
            }

            VStack(spacing: 4) {
                Text("\(Int(state.coherence * 100))%")
                    .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.green)
                Text("Coherence")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
    }
}

struct CollaborationStrip: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.cyan)
            Text("0 participants")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text("Group Coherence: \(Int(engine.state.coherence * 100))%")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.green)
        }
        .padding(16)
    }
}

// MARK: - Reusable Inspector Components

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
            content
        }
    }
}

struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
