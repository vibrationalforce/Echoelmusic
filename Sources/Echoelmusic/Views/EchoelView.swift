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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        #endif
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EngineMode.allCases) { mode in
                    EngineModeButton(
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
        case .collaboration:
            CollaborationOverlay(engine: engine)
        case .immersive:
            ImmersiveOverlay(engine: engine)
        case .research:
            ResearchOverlay(engine: engine)
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
                    .accessibilityHidden(true)
                Text("\(Int(engine.state.heartRate))")
                    .font(.system(size: 12, design: .monospaced))
            }

            // Coherence
            HStack(spacing: 4) {
                Circle()
                    .fill(coherenceColor(engine.state.coherence))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("\(Int(engine.state.coherence * 100))%")
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .foregroundColor(.white.opacity(0.7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate \(Int(engine.state.heartRate)) BPM, coherence \(Int(engine.state.coherence * 100)) percent")
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
                .accessibilityHidden(true)
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

private struct EngineModeButton: View {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .animation(reduceMotion ? nil : .easeInOut(duration: 2), value: breathPhase)

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
    @State private var isArmed = false
    @State private var metronomeOn = false
    @State private var inputMonitor = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Spacer()

                // Input level meter
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                        .foregroundColor(inputMonitor ? .green : .white.opacity(0.4))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.6))
                        .frame(width: CGFloat(max(engine.state.audioLevel, 0.05)) * 60, height: 8)
                        .animation(reduceMotion ? nil : .linear(duration: 0.05), value: engine.state.audioLevel)
                }
                .frame(minHeight: 44)
                .onTapGesture { inputMonitor.toggle() }
                .accessibilityLabel("Input monitor, \(inputMonitor ? "enabled" : "disabled")")

                // Metronome
                Button(action: { metronomeOn.toggle() }) {
                    Image(systemName: metronomeOn ? "metronome.fill" : "metronome")
                        .font(.system(size: 14))
                        .foregroundColor(metronomeOn ? .orange : .white.opacity(0.5))
                        .padding(6)
                        .background(metronomeOn ? Color.orange.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Metronome, \(metronomeOn ? "on" : "off")")

                // Record arm
                Button(action: {
                    isArmed.toggle()
                    if isArmed { engine.eventBus.send(.record) }
                }) {
                    Circle()
                        .fill(isArmed ? Color.red : Color.red.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.red, lineWidth: isArmed ? 0 : 1)
                        )
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Record, \(isArmed ? "armed" : "disarmed")")

                // Recording indicator
                if engine.state.isRecording {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("REC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct LiveOverlay: View {
    @ObservedObject var engine: EchoelEngine
    @State private var selectedScene = 0
    private let sceneNames = ["Intro", "Verse", "Chorus", "Bridge", "Drop", "Outro"]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    // Streaming status
                    if engine.state.isStreaming {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(4)
                    }

                    // Scene triggers
                    VStack(spacing: 4) {
                        ForEach(0..<sceneNames.count, id: \.self) { i in
                            Button(action: { selectedScene = i }) {
                                Text(sceneNames[i])
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(selectedScene == i ? .black : .white.opacity(0.7))
                                    .frame(width: 64, height: 24)
                                    .background(selectedScene == i ? Color.orange : Color.white.opacity(0.1))
                                    .cornerRadius(4)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Scene \(sceneNames[i]), \(selectedScene == i ? "active" : "inactive")")
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            Spacer()

            // Effect trigger pads
            HStack(spacing: 8) {
                Spacer()
                ForEach(["Filter", "Stutter", "Reverb", "Delay"], id: \.self) { fx in
                    Text(fx)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 56, height: 56)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }
}

struct MeditationOverlay: View {
    @ObservedObject var engine: EchoelEngine
    @State private var sessionSeconds: Int = 0
    @State private var targetMinutes: Int = 10
    @State private var sessionActive = false
    @State private var timer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            // Session timer
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text(formatSessionTime(sessionSeconds))
                        .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.white)
                    Text("/ \(targetMinutes):00")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))

                    Button(action: { toggleSession() }) {
                        Text(sessionActive ? "End" : "Begin")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(sessionActive ? Color.red.opacity(0.5) : Color.cyan.opacity(0.5))
                            .cornerRadius(16)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .accessibilityLabel(sessionActive ? "End meditation session" : "Begin meditation session")
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }

            Spacer()

            // Coherence target ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: CGFloat(engine.state.coherence))
                    .stroke(
                        Color.green.opacity(Double(engine.state.coherence)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1), value: engine.state.coherence)
            }

            Spacer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            sessionActive = false
        }
    }

    private func toggleSession() {
        if sessionActive {
            timer?.invalidate()
            timer = nil
            sessionActive = false
        } else {
            sessionSeconds = 0
            sessionActive = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak engine] _ in
                guard engine != nil else { return }
                Task { @MainActor in
                    sessionSeconds += 1
                }
            }
        }
    }

    private func formatSessionTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct VideoOverlay: View {
    @ObservedObject var engine: EchoelEngine
    @State private var selectedExport = "H.265"
    @State private var selectedResolution = "4K"
    private let exports = ["H.264", "H.265", "ProRes", "AV1"]
    private let resolutions = ["1080p", "4K", "8K"]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    // Resolution picker
                    HStack(spacing: 4) {
                        ForEach(resolutions, id: \.self) { res in
                            Button(action: { selectedResolution = res }) {
                                Text(res)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(selectedResolution == res ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedResolution == res ? Color.yellow : Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Export format
                    HStack(spacing: 4) {
                        ForEach(exports, id: \.self) { fmt in
                            Button(action: { selectedExport = fmt }) {
                                Text(fmt)
                                    .font(.system(size: 9))
                                    .foregroundColor(selectedExport == fmt ? .black : .white.opacity(0.6))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(selectedExport == fmt ? Color.cyan : Color.white.opacity(0.08))
                                    .cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            Spacer()

            // Timeline position bar
            HStack(spacing: 8) {
                Text(formatVideoTime(engine.state.position))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: max(0, CGFloat(engine.state.position.truncatingRemainder(dividingBy: 60)) / 60 * geo.size.width))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }

    private func formatVideoTime(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        let f = Int((t.truncatingRemainder(dividingBy: 1)) * 30) // 30fps frame count
        return String(format: "%02d:%02d:%02d:%02d", h, m, s, f)
    }
}

struct DJOverlay: View {
    @ObservedObject var engine: EchoelEngine
    @State private var crossfader: Float = 0.5
    @State private var deckABPM: Double = 128
    @State private var deckBBPM: Double = 128
    @State private var syncEnabled = true

    var body: some View {
        VStack {
            // Deck BPM displays
            HStack {
                VStack(spacing: 2) {
                    Text("DECK A")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.8))
                    Text("\(String(format: "%.1f", deckABPM))")
                        .font(.system(size: 18, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.leading, 16)

                Spacer()

                // Sync button
                Button(action: {
                    syncEnabled.toggle()
                    if syncEnabled { deckBBPM = deckABPM }
                }) {
                    Text("SYNC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(syncEnabled ? .black : .white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(syncEnabled ? Color.green : Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("DECK B")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange.opacity(0.8))
                    Text("\(String(format: "%.1f", deckBBPM))")
                        .font(.system(size: 18, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 8)

            Spacer()

            // Crossfader
            VStack(spacing: 4) {
                HStack {
                    Text("A").font(.system(size: 10)).foregroundColor(.cyan.opacity(0.6))
                    Spacer()
                    Text("B").font(.system(size: 10)).foregroundColor(.orange.opacity(0.6))
                }
                .padding(.horizontal, 4)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.5), .orange.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        // Crossfader knob
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .offset(x: CGFloat(crossfader) * (geo.size.width - 16))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        crossfader = Float(max(0, min(1, value.location.x / geo.size.width)))
                                    }
                            )
                    }
                }
                .frame(height: 16)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 80)
        }
    }
}

struct CollaborationOverlay: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    // Participant count
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        Text("\(engine.state.participantCount)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(6)

                    // Group coherence
                    HStack(spacing: 4) {
                        Circle()
                            .fill(engine.state.groupCoherence > 0.7 ? Color.green : Color.yellow)
                            .frame(width: 6, height: 6)
                        Text("Group: \(Int(engine.state.groupCoherence * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Streaming status
                    if engine.state.isStreaming {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("Broadcasting")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

struct ImmersiveOverlay: View {
    @ObservedObject var engine: EchoelEngine

    var body: some View {
        VStack {
            HStack {
                // Hand tracking status
                if engine.state.handsTracked {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("Hands Tracked")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        HStack(spacing: 12) {
                            HStack(spacing: 2) {
                                Text("L")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("\(Int(engine.state.leftPinch * 100))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            HStack(spacing: 2) {
                                Text("R")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("\(Int(engine.state.rightPinch * 100))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)
                }

                Spacer()

                // Quantum coherence
                VStack(spacing: 4) {
                    Text("\(Int(engine.state.quantumCoherence * 100))%")
                        .font(.system(size: 16, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.purple)
                    Text("Quantum")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

struct ResearchOverlay: View {
    @ObservedObject var engine: EchoelEngine
    @State private var isExporting = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    // Circadian phase
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(engine.state.circadianPhase)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Recording indicator
                    if engine.state.isRecording {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("Recording Data")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Export button
                    Button(action: { isExporting = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10))
                            Text("Export CSV")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            Spacer()
        }
    }
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
    @State private var trackStates: [(name: String, armed: Bool, muted: Bool, solo: Bool, level: Float)] = [
        ("Audio 1", false, false, false, 0.7),
        ("Audio 2", false, false, false, 0.5),
        ("MIDI 1", false, false, false, 0.6),
        ("MIDI 2", false, false, false, 0.4),
        ("Bus A", false, false, false, 0.8),
        ("Bus B", false, false, false, 0.6),
        ("Master", false, false, false, 0.85)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tracks")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { addTrack() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(0..<trackStates.count, id: \.self) { i in
                        HStack(spacing: 6) {
                            // Track name
                            Text(trackStates[i].name)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 60, alignment: .leading)
                                .lineLimit(1)

                            Spacer()

                            // Arm
                            Button(action: { trackStates[i].armed.toggle() }) {
                                Circle()
                                    .fill(trackStates[i].armed ? Color.red : Color.red.opacity(0.2))
                                    .frame(width: 14, height: 14)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(trackStates[i].name) arm, \(trackStates[i].armed ? "armed" : "disarmed")")

                            // Mute
                            Button(action: { trackStates[i].muted.toggle() }) {
                                Text("M")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(trackStates[i].muted ? .black : .white.opacity(0.5))
                                    .frame(width: 18, height: 18)
                                    .background(trackStates[i].muted ? Color.yellow : Color.white.opacity(0.1))
                                    .cornerRadius(3)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(trackStates[i].name) mute, \(trackStates[i].muted ? "muted" : "unmuted")")

                            // Solo
                            Button(action: { trackStates[i].solo.toggle() }) {
                                Text("S")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(trackStates[i].solo ? .black : .white.opacity(0.5))
                                    .frame(width: 18, height: 18)
                                    .background(trackStates[i].solo ? Color.cyan : Color.white.opacity(0.1))
                                    .cornerRadius(3)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(trackStates[i].name) solo, \(trackStates[i].solo ? "soloed" : "off")")

                            // Level
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.green.opacity(0.5))
                                .frame(width: CGFloat(trackStates[i].level) * 30, height: 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(i % 2 == 0 ? 0.03 : 0))
                    }
                }
            }
        }
    }

    private func addTrack() {
        let count = trackStates.count
        trackStates.append(("Audio \(count)", false, false, false, 0.5))
    }
}

struct ScenesPanel: View {
    @ObservedObject var engine: EchoelEngine
    @State private var scenes: [String] = ["Intro", "Verse", "Chorus", "Bridge", "Drop", "Outro"]
    @State private var activeScene: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Scenes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { scenes.append("Scene \(scenes.count + 1)") }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(0..<scenes.count, id: \.self) { i in
                        Button(action: { activeScene = i }) {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(activeScene == i ? sceneColor(i).opacity(0.6) : Color.white.opacity(0.08))
                                    .frame(height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(activeScene == i ? sceneColor(i) : Color.clear, lineWidth: 1)
                                    )
                                Text(scenes[i])
                                    .font(.system(size: 10))
                                    .foregroundColor(activeScene == i ? .white : .white.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()
        }
    }

    private func sceneColor(_ index: Int) -> Color {
        let colors: [Color] = [.cyan, .purple, .orange, .green, .pink, .yellow, .blue, .red]
        return colors[index % colors.count]
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
    @State private var fxChain: [(name: String, enabled: Bool, mix: Float)] = [
        ("EQ", true, 1.0),
        ("Compressor", true, 0.8),
        ("Reverb", true, 0.35),
        ("Delay", false, 0.25),
        ("Saturation", false, 0.5)
    ]
    @State private var sendA: Float = 0.3
    @State private var sendB: Float = 0.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Insert FX chain
                InspectorSection(title: "Insert Chain") {
                    ForEach(0..<fxChain.count, id: \.self) { i in
                        HStack(spacing: 8) {
                            // Enable toggle
                            Button(action: { fxChain[i].enabled.toggle() }) {
                                Image(systemName: "power")
                                    .font(.system(size: 10))
                                    .foregroundColor(fxChain[i].enabled ? .green : .white.opacity(0.3))
                            }
                            .buttonStyle(.plain)

                            Text(fxChain[i].name)
                                .font(.system(size: 12))
                                .foregroundColor(fxChain[i].enabled ? .white : .white.opacity(0.4))

                            Spacer()

                            // Mix amount bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 50, height: 6)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(fxChain[i].enabled ? Color.cyan.opacity(0.6) : Color.white.opacity(0.15))
                                    .frame(width: CGFloat(fxChain[i].mix) * 50, height: 6)
                            }

                            Text("\(Int(fxChain[i].mix * 100))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }

                // Send levels
                InspectorSection(title: "Sends") {
                    HStack {
                        Text("Send A (Reverb)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(sendA * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    HStack {
                        Text("Send B (Delay)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(sendB * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }

                // Master output
                InspectorSection(title: "Output") {
                    InspectorRow(label: "Level", value: "\(Int(engine.state.audioLevel * 100))%")
                    InspectorRow(label: "Pan", value: "C")
                    InspectorRow(label: "Width", value: "100%")
                }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1), value: state.breathPhase)
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
            Text("\(engine.state.participantCount) participant\(engine.state.participantCount == 1 ? "" : "s")")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // Individual coherence
            VStack(spacing: 2) {
                Text("You: \(Int(engine.state.coherence * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyan)
                Text("Group: \(Int(engine.state.groupCoherence * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green)
            }

            // Streaming toggle indicator
            if engine.state.isStreaming {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
                .padding(.leading, 8)
            }
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
