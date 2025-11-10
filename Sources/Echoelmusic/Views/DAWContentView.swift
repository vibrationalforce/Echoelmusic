import SwiftUI

/// Professional DAW Interface for Echoelmusic
/// FULL USER CONTROL - Professional music production tool
/// NOT AI-generated music - Tools for users to create their OWN work
@MainActor
struct DAWContentView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager

    // MARK: - State Objects

    @StateObject private var dawCore = DAWCore()
    @StateObject private var synthEngine = SynthEngine()
    @StateObject private var effectChainBuilder = EffectChainBuilder()
    @StateObject private var debugConsole = DebugConsole.shared

    // MARK: - State Variables

    @State private var selectedTab: DAWTab = .sequencer
    @State private var showDebugConsole = false
    @State private var showSettings = false
    @State private var selectedTrack: UUID?
    @State private var selectedClip: UUID?

    // MARK: - DAW Tabs

    enum DAWTab: String, CaseIterable {
        case sequencer = "Sequencer"
        case mixer = "Mixer"
        case synth = "Synth"
        case effects = "Effects"
        case browser = "Browser"

        var icon: String {
            switch self {
            case .sequencer: return "waveform.path"
            case .mixer: return "slider.vertical.3"
            case .synth: return "waveform.and.magnifyingglass"
            case .effects: return "sparkles"
            case .browser: return "folder"
            }
        }
    }

    var body: some View {
        ZStack {
            // Main DAW Interface
            VStack(spacing: 0) {
                // Top Bar
                topBar

                Divider()

                // Transport Controls
                transportControls
                    .frame(height: 60)

                Divider()

                // Main Content Area
                HStack(spacing: 0) {
                    // Left Sidebar - Tab Selector
                    VStack(spacing: 0) {
                        ForEach(DAWTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.title2)
                                    Text(tab.rawValue)
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 80)
                                .background(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            if tab != DAWTab.allCases.last {
                                Divider()
                            }
                        }

                        Spacer()

                        // Debug Console Toggle
                        Button(action: {
                            showDebugConsole.toggle()
                            debugConsole.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "ant.circle")
                                    .font(.title2)
                                Text("Debug")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 80)
                            .background(showDebugConsole ? Color.red.opacity(0.2) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 80)
                    .background(Color.secondary.opacity(0.05))

                    Divider()

                    // Main Content
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Debug Console Overlay
                if showDebugConsole {
                    Divider()
                    DebugConsoleView()
                }
            }

            // Loading/Error Overlays
            // (Can be added later)
        }
        .onAppear {
            setupDAW()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Project Info
            VStack(alignment: .leading, spacing: 2) {
                Text(dawCore.project.name)
                    .font(.headline)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "metronome")
                        Text("\(Int(dawCore.project.tempo)) BPM")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                        Text("\(dawCore.project.timeSignature.numerator)/\(dawCore.project.timeSignature.denominator)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.leading)

            Spacer()

            // Performance Indicators
            HStack(spacing: 12) {
                // CPU Meter
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    Text("\(Int(debugConsole.performanceMetrics.cpuUsage))%")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundColor(debugConsole.performanceMetrics.cpuUsage > 80 ? .red : .secondary)

                // Active Voices
                HStack(spacing: 4) {
                    Image(systemName: "music.note.list")
                    Text("\(synthEngine.voices.count)")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)

                Button(action: { Task { await saveProject() } }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing)
        }
        .frame(height: 50)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 20) {
            // Playback Position
            Text(formatTime(dawCore.playbackPosition))
                .font(.system(.title3, design: .monospaced))
                .frame(width: 120)

            Spacer()

            // Transport Buttons
            HStack(spacing: 16) {
                // Rewind
                Button(action: { dawCore.setPlaybackPosition(0) }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                // Play/Stop
                Button(action: {
                    if dawCore.transportState == .playing {
                        dawCore.stop()
                    } else {
                        dawCore.play()
                    }
                }) {
                    Image(systemName: dawCore.transportState == .playing ? "stop.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .foregroundColor(dawCore.transportState == .playing ? .blue : .primary)

                // Record
                Button(action: { dawCore.record() }) {
                    Image(systemName: "record.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(dawCore.transportState == .recording ? .red : .primary)

                // Loop
                Button(action: { dawCore.toggleLoop() }) {
                    Image(systemName: "repeat")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(dawCore.loopEnabled ? .blue : .primary)
            }

            Spacer()

            // Tempo Control
            HStack(spacing: 8) {
                Button(action: { dawCore.setTempo(dawCore.project.tempo - 1) }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)

                Text("\(Int(dawCore.project.tempo))")
                    .font(.system(.title3, design: .monospaced))
                    .frame(width: 60)

                Button(action: { dawCore.setTempo(dawCore.project.tempo + 1) }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Text("BPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .sequencer:
            SequencerView(dawCore: dawCore, selectedTrack: $selectedTrack, selectedClip: $selectedClip)
        case .mixer:
            MixerView(dawCore: dawCore)
        case .synth:
            SynthView(synthEngine: synthEngine)
        case .effects:
            EffectChainView(effectChainBuilder: effectChainBuilder)
        case .browser:
            BrowserView()
        }
    }

    // MARK: - Setup

    private func setupDAW() {
        debugConsole.info("DAW Interface initialized")
        debugConsole.info("Project: \(dawCore.project.name)")
        debugConsole.info("Tempo: \(dawCore.project.tempo) BPM")
        debugConsole.info("Time Signature: \(dawCore.project.timeSignature.numerator)/\(dawCore.project.timeSignature.denominator)")
    }

    private func saveProject() async {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("project.json")
            try await dawCore.saveProject(to: url)
            debugConsole.info("Project saved successfully")
        } catch {
            debugConsole.logError(error, context: "Failed to save project")
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, ms)
    }
}

// MARK: - Sequencer View

struct SequencerView: View {
    @ObservedObject var dawCore: DAWCore
    @Binding var selectedTrack: UUID?
    @Binding var selectedClip: UUID?

    @State private var showAddTrackMenu = false
    @State private var zoom: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Sequencer")
                    .font(.headline)

                Spacer()

                // Zoom Controls
                HStack {
                    Button(action: { zoom = max(0.5, zoom - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }

                    Text("\(Int(zoom * 100))%")
                        .font(.caption)
                        .frame(width: 50)

                    Button(action: { zoom = min(2.0, zoom + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
                .buttonStyle(.plain)

                // Add Track
                Button(action: { showAddTrackMenu.toggle() }) {
                    Label("Add Track", systemImage: "plus")
                }
                .popover(isPresented: $showAddTrackMenu) {
                    AddTrackMenu(dawCore: dawCore)
                }
            }
            .padding()

            Divider()

            // Track List + Timeline
            HStack(spacing: 0) {
                // Track Headers
                VStack(spacing: 0) {
                    ForEach(dawCore.project.tracks) { track in
                        TrackHeaderView(track: track, dawCore: dawCore, isSelected: selectedTrack == track.id)
                            .onTapGesture {
                                selectedTrack = track.id
                            }
                    }
                }
                .frame(width: 200)

                Divider()

                // Timeline
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        // Ruler
                        TimelineRuler(duration: 32, zoom: zoom)
                            .frame(height: 40)

                        // Clip Lanes
                        ForEach(dawCore.project.tracks) { track in
                            ClipLaneView(track: track, dawCore: dawCore, zoom: zoom, selectedClip: $selectedClip)
                        }
                    }
                }
            }
        }
    }
}

struct TrackHeaderView: View {
    let track: DAWCore.Track
    @ObservedObject var dawCore: DAWCore
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: track.type == .midi ? "pianokeys" : "waveform")
                Text(track.name)
                    .font(.callout)
                Spacer()
            }

            HStack {
                // Mute
                Button(action: { dawCore.toggleMute(trackId: track.id) }) {
                    Text("M")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .background(track.isMuted ? Color.orange : Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Solo
                Button(action: { dawCore.toggleSolo(trackId: track.id) }) {
                    Text("S")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .background(track.isSolo ? Color.yellow : Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Arm
                Button(action: { dawCore.toggleArm(trackId: track.id) }) {
                    Image(systemName: "record.circle")
                        .frame(width: 24, height: 24)
                        .foregroundColor(track.isArmed ? .red : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(8)
        .frame(height: 60)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.05))
    }
}

struct ClipLaneView: View {
    let track: DAWCore.Track
    @ObservedObject var dawCore: DAWCore
    let zoom: CGFloat
    @Binding var selectedClip: UUID?

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            Color.secondary.opacity(0.03)

            // Clips
            ForEach(track.clips) { clip in
                ClipView(clip: clip, zoom: zoom, isSelected: selectedClip == clip.id)
                    .offset(x: clip.startTime * 100 * zoom)
                    .onTapGesture {
                        selectedClip = clip.id
                    }
            }
        }
        .frame(height: 60)
    }
}

struct ClipView: View {
    let clip: DAWCore.Clip
    let zoom: CGFloat
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(clipColor.opacity(isSelected ? 0.8 : 0.6))
            .frame(width: clip.duration * 100 * zoom, height: 50)
            .overlay(
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.leading, 4),
                alignment: .leading
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
    }

    private var clipColor: Color {
        switch clip.type {
        case .midi: return .blue
        case .audio: return .green
        case .automation: return .orange
        }
    }
}

struct TimelineRuler: View {
    let duration: Int
    let zoom: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<duration, id: \.self) { bar in
                VStack(alignment: .leading) {
                    Text("\(bar + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(width: 100 * zoom, height: 40)
                .border(Color.secondary.opacity(0.3), width: 0.5)
            }
        }
    }
}

struct AddTrackMenu: View {
    @ObservedObject var dawCore: DAWCore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("MIDI Track") {
                _ = dawCore.createTrack(name: "MIDI \(dawCore.project.tracks.count + 1)", type: .midi)
                dismiss()
            }

            Button("Audio Track") {
                _ = dawCore.createTrack(name: "Audio \(dawCore.project.tracks.count + 1)", type: .audio)
                dismiss()
            }

            Button("Group Track") {
                _ = dawCore.createTrack(name: "Group \(dawCore.project.tracks.count + 1)", type: .group)
                dismiss()
            }

            Button("Aux Track") {
                _ = dawCore.createTrack(name: "Aux \(dawCore.project.tracks.count + 1)", type: .aux)
                dismiss()
            }
        }
        .padding()
        .buttonStyle(.plain)
    }
}

// MARK: - Mixer View (Placeholder)

struct MixerView: View {
    @ObservedObject var dawCore: DAWCore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(dawCore.project.tracks) { track in
                    ChannelStripView(track: track, dawCore: dawCore)
                }

                // Master Channel
                MasterChannelStripView(dawCore: dawCore)
            }
            .padding()
        }
    }
}

struct ChannelStripView: View {
    let track: DAWCore.Track
    @ObservedObject var dawCore: DAWCore

    var body: some View {
        VStack(spacing: 8) {
            Text(track.name)
                .font(.caption)

            // Fader
            VStack {
                Slider(value: .constant(track.mixerChannel.volume), in: 0...1)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 200)
            }

            // Pan Knob
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(Text("PAN").font(.caption2))

            // Meter
            Rectangle()
                .fill(Color.green)
                .frame(width: 20, height: 100)

            // M/S Buttons
            HStack {
                Text("M").font(.caption2)
                Text("S").font(.caption2)
            }
        }
        .frame(width: 60)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MasterChannelStripView: View {
    @ObservedObject var dawCore: DAWCore

    var body: some View {
        VStack {
            Text("MASTER")
                .font(.caption)
                .bold()

            Slider(value: .constant(dawCore.project.masterChannel.volume), in: 0...1)
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 200)

            Rectangle()
                .fill(Color.blue)
                .frame(width: 20, height: 100)
        }
        .frame(width: 80)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Synth View (Placeholder)

struct SynthView: View {
    @ObservedObject var synthEngine: SynthEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Synth Engine")
                    .font(.title)

                Text("Oscillators, Filters, Envelopes, LFOs")
                    .foregroundColor(.secondary)

                Text("Coming soon...")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Effect Chain View (Placeholder)

struct EffectChainView: View {
    @ObservedObject var effectChainBuilder: EffectChainBuilder

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Effect Chain Builder")
                    .font(.title)

                Text("Drag & Drop Effects")
                    .foregroundColor(.secondary)

                Text("Coming soon...")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Browser View (Placeholder)

struct BrowserView: View {
    var body: some View {
        VStack {
            Text("Browser")
                .font(.title)

            Text("Presets, Samples, Projects")
                .foregroundColor(.secondary)

            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
    }
}
