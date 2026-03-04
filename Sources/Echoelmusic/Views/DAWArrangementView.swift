import SwiftUI
import Accelerate

// MARK: - DAW Arrangement View
// Professional DAW arrangement with REAL audio engine integration

struct DAWArrangementView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var recordingEngine: RecordingEngine
    @ObservedObject private var workspace = EchoelCreativeWorkspace.shared

    @StateObject private var metronome = MetronomeEngine()

    @State private var selectedTrackID: UUID?
    @State private var timelineZoom: Double = 1.0
    @State private var showMixer = false
    @State private var showInstrumentBrowser = false
    @State private var showTrackList = true
    @State private var showSessionClips = false
    @State private var showEffectsChain = false
    @State private var playbackTimer: Timer?
    @State private var scrollOffset: CGFloat = 0

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var trackListWidth: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 120 : 180
        #else
        return 180
        #endif
    }

    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var bpm: Double { workspace.globalBPM }
    private var isPlaying: Bool { recordingEngine.isPlaying }
    private var isRecording: Bool { recordingEngine.isRecording }

    /// Pixels per second at current zoom
    private var pixelsPerSecond: CGFloat { 50.0 * timelineZoom }

    /// Tracks from real session
    private var tracks: [Track] {
        recordingEngine.currentSession?.tracks ?? []
    }

    var body: some View {
        ZStack {
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                HStack(spacing: 0) {
                    if showTrackList || !isCompact {
                        trackListSection
                    }
                    arrangementSection
                }
                dawTransportBar
            }

            if showInstrumentBrowser {
                instrumentBrowserOverlay
            }
        }
        .sheet(isPresented: $showMixer) {
            RealMixerSheet()
                .environmentObject(audioEngine)
                .environmentObject(recordingEngine)
        }
        .sheet(isPresented: $showSessionClips) {
            SessionClipView()
        }
        .sheet(isPresented: $showEffectsChain) {
            EffectsChainView()
        }
        .onAppear {
            ensureSessionExists()
        }
        .onDisappear {
            metronome.stop()
        }
        // Cycle 12: Keyboard shortcuts (Cmd+key for compatibility)
        .background(
            Group {
                Button { togglePlayback(); HapticHelper.impact(.medium) } label: { EmptyView() }
                    .keyboardShortcut(.space, modifiers: [])
                Button { toggleRecording(); HapticHelper.impact(.heavy) } label: { EmptyView() }
                    .keyboardShortcut("r", modifiers: [])
                Button { recordingEngine.undo(); HapticHelper.impact(.light) } label: { EmptyView() }
                    .keyboardShortcut("z", modifiers: .command)
                Button { recordingEngine.redo(); HapticHelper.impact(.light) } label: { EmptyView() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                Button { showMixer = true } label: { EmptyView() }
                    .keyboardShortcut("m", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }

    /// Create a session if none exists
    private func ensureSessionExists() {
        if recordingEngine.currentSession == nil {
            _ = recordingEngine.createSession(name: "New Project", template: .custom)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                Text(recordingEngine.currentSession?.name.uppercased() ?? "DAW STUDIO")
                    .font(EchoelBrandFont.sectionTitle())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text("\(tracks.count) Tracks • \(formatDuration(recordingEngine.currentSession?.duration ?? 0))")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)
            }

            Spacer()

            // BPM + Metronome toggle
            Button {
                if metronome.isRunning {
                    metronome.stop()
                } else {
                    metronome.setTempo(bpm)
                    metronome.start()
                }
                HapticHelper.impact(.light)
            } label: {
                HStack(spacing: EchoelSpacing.sm) {
                    Image(systemName: metronome.isRunning ? "metronome.fill" : "metronome")
                        .foregroundColor(metronome.isRunning ? EchoelBrand.coral : EchoelBrand.textSecondary)
                        .opacity(metronome.beatFlash ? 1.0 : 0.7)
                    Text("\(Int(bpm))")
                        .font(EchoelBrandFont.data())
                        .foregroundColor(EchoelBrand.textPrimary)
                    Text("BPM")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(metronome.isRunning ? EchoelBrand.coral.opacity(0.1) : Color.clear)
            )
            .modifier(GlassCard())

            Spacer()

            // Toolbar
            HStack(spacing: EchoelSpacing.sm) {
                if isCompact {
                    toolbarButton(icon: "sidebar.left", label: "Tracks", isActive: showTrackList) {
                        withAnimation(.easeInOut(duration: 0.2)) { showTrackList.toggle() }
                    }
                }
                toolbarButton(icon: "slider.horizontal.3", label: "Mixer", isActive: showMixer) {
                    showMixer = true
                }
                toolbarButton(icon: "square.grid.3x3", label: "Clips", isActive: showSessionClips) {
                    showSessionClips = true
                }
                toolbarButton(icon: "waveform.path.ecg", label: "FX", isActive: showEffectsChain) {
                    showEffectsChain = true
                }
                toolbarButton(icon: "plus.circle", label: "Add", isActive: false) {
                    addNewTrack()
                }
            }
        }
        .padding(EchoelSpacing.md)
    }

    // MARK: - Track List

    private var trackListSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRACKS")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(2)
                Spacer()
                Button { addNewTrack() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(EchoelBrand.sky)
                }
            }
            .padding(EchoelSpacing.sm)

            ScrollView {
                VStack(spacing: EchoelSpacing.xs) {
                    ForEach(tracks) { track in
                        trackRow(track: track)
                    }
                }
                .padding(.horizontal, EchoelSpacing.sm)
            }
        }
        .frame(width: trackListWidth)
        .background(EchoelBrand.bgDeep.opacity(0.5))
    }

    private func trackRow(track: Track) -> some View {
        let isSelected = selectedTrackID == track.id
        let trackColor = color(for: track.trackColor)

        return HStack(spacing: EchoelSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(trackColor)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .lineLimit(1)
                Text(track.type.rawValue)
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                miniButton(label: "M", isActive: track.isMuted, color: EchoelBrand.coral) {
                    recordingEngine.setTrackMuted(track.id, muted: !track.isMuted)
                }
                miniButton(label: "S", isActive: track.isSoloed, color: EchoelBrand.sky) {
                    recordingEngine.setTrackSoloed(track.id, soloed: !track.isSoloed)
                }
            }
        }
        .padding(EchoelSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? trackColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? trackColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture { selectedTrackID = track.id }
    }

    // MARK: - Arrangement Timeline

    private var arrangementSection: some View {
        VStack(spacing: 0) {
            timelineRuler

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Track lanes
                    VStack(spacing: EchoelSpacing.xs) {
                        ForEach(tracks) { track in
                            trackLane(track: track)
                        }

                        // Empty area for adding tracks
                        if tracks.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(EchoelSpacing.sm)

                    // Playhead overlay
                    playheadView
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        timelineZoom = max(0.25, min(4.0, value))
                    }
            )

            // Zoom control
            zoomControl
        }
        .modifier(GlassCard())
        .padding(EchoelSpacing.md)
    }

    private var emptyStateView: some View {
        VStack(spacing: EchoelSpacing.md) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(EchoelBrand.textTertiary)

            Text("Tap Record or Add Track to start")
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.textSecondary)

            Button {
                addNewTrack()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Track")
                }
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.sky)
                .padding(.horizontal, EchoelSpacing.lg)
                .padding(.vertical, EchoelSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(EchoelBrand.sky.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var timelineRuler: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Bar markers
                let totalBars = max(16, Int(ceil((recordingEngine.currentSession?.duration ?? 30) * bpm / 240.0)) + 4)
                let barWidth = (240.0 / bpm) * pixelsPerSecond // 4 beats per bar

                HStack(spacing: 0) {
                    ForEach(0..<totalBars, id: \.self) { bar in
                        VStack {
                            Text("\(bar + 1)")
                                .font(EchoelBrandFont.caption())
                                .foregroundColor(bar % 4 == 0 ? EchoelBrand.textSecondary : EchoelBrand.textTertiary)
                            Spacer()
                        }
                        .frame(width: barWidth)
                    }
                }

                // Playhead
                Rectangle()
                    .fill(EchoelBrand.coral)
                    .frame(width: 2)
                    .offset(x: CGFloat(recordingEngine.currentTime) * pixelsPerSecond)
                    .shadow(color: EchoelBrand.coral.opacity(0.4), radius: 6)
            }
        }
        .frame(height: 30)
        .background(EchoelBrand.bgDeep.opacity(0.5))
    }

    private var playheadView: some View {
        Rectangle()
            .fill(EchoelBrand.coral.opacity(0.3))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .offset(x: CGFloat(recordingEngine.currentTime) * pixelsPerSecond + EchoelSpacing.sm)
    }

    private func trackLane(track: Track) -> some View {
        let isSelected = selectedTrackID == track.id
        let trackColor = color(for: track.trackColor)
        let laneWidth = max(300, CGFloat(track.duration) * pixelsPerSecond + 20)

        return ZStack(alignment: .leading) {
            // Lane background
            RoundedRectangle(cornerRadius: 4)
                .fill(EchoelBrand.bgDeep.opacity(0.3))
                .frame(width: laneWidth, height: 60)

            // Audio region with waveform
            if track.duration > 0 {
                audioRegionView(track: track, trackColor: trackColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? trackColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    /// Renders a real audio region with waveform data
    private func audioRegionView(track: Track, trackColor: Color) -> some View {
        let regionWidth = CGFloat(track.duration) * pixelsPerSecond

        return ZStack(alignment: .leading) {
            // Region background
            RoundedRectangle(cornerRadius: 4)
                .fill(trackColor.opacity(0.2))
                .frame(width: regionWidth, height: 56)

            // Waveform
            if let waveformData = track.waveformData, !waveformData.isEmpty {
                WaveformShape(samples: waveformData)
                    .fill(trackColor.opacity(0.8))
                    .frame(width: regionWidth, height: 40)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 8)
            } else {
                // Loading / recording indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(trackColor.opacity(0.3))
                    .frame(width: regionWidth - 4, height: 20)
                    .padding(.horizontal, 2)
            }

            // Region border
            RoundedRectangle(cornerRadius: 4)
                .stroke(trackColor.opacity(0.6), lineWidth: 1)
                .frame(width: regionWidth, height: 56)

            // Track name label
            Text(track.name)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textPrimary)
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .frame(width: regionWidth, alignment: .leading)
                .offset(y: -20)
        }
    }

    // MARK: - Zoom Control

    private var zoomControl: some View {
        HStack(spacing: EchoelSpacing.sm) {
            Button {
                withAnimation { timelineZoom = max(0.25, timelineZoom - 0.25) }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)

            Text("\(Int(timelineZoom * 100))%")
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textTertiary)
                .frame(width: 40)

            Button {
                withAnimation { timelineZoom = min(4.0, timelineZoom + 0.25) }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, EchoelSpacing.md)
    }

    // MARK: - DAW Transport Bar

    private var dawTransportBar: some View {
        HStack(spacing: EchoelSpacing.lg) {
            // Position display
            VStack(spacing: 2) {
                Text(formatPosition(recordingEngine.currentTime))
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundColor(EchoelBrand.textPrimary)
                Text("POSITION")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textTertiary)
            }
            .frame(width: 80)

            Spacer()

            // Transport controls
            HStack(spacing: EchoelSpacing.md) {
                transportButton(icon: "backward.end.fill") {
                    recordingEngine.seek(to: 0)
                }

                transportButton(icon: "backward.fill") {
                    recordingEngine.seek(to: max(0, recordingEngine.currentTime - 5))
                }

                // Play/Stop
                Button { togglePlayback() } label: {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? EchoelBrand.coral.opacity(0.3) : EchoelBrand.sky.opacity(0.2))
                            .frame(width: 52, height: 52)
                        Circle()
                            .stroke(isPlaying ? EchoelBrand.coral : EchoelBrand.sky, lineWidth: 2)
                            .frame(width: 52, height: 52)
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isPlaying ? EchoelBrand.coral : EchoelBrand.sky)
                    }
                    .shadow(color: (isPlaying ? EchoelBrand.coral : EchoelBrand.sky).opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)

                // Record
                Button { toggleRecording() } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? EchoelBrand.coral.opacity(0.3) : Color.clear)
                            .frame(width: 42, height: 42)
                        Circle()
                            .stroke(EchoelBrand.coral, lineWidth: 2)
                            .frame(width: 42, height: 42)
                        Circle()
                            .fill(EchoelBrand.coral)
                            .frame(width: 14, height: 14)
                    }
                    .shadow(color: isRecording ? EchoelBrand.coral.opacity(0.5) : .clear, radius: isRecording ? 10 : 0)
                }
                .buttonStyle(.plain)

                transportButton(icon: "forward.fill") {
                    recordingEngine.seek(to: recordingEngine.currentTime + 5)
                }
            }

            Spacer()

            // Live master meter
            masterMeter
                .frame(width: 80)
        }
        .padding(EchoelSpacing.md)
        .background(EchoelBrand.bgDeep.opacity(0.8))
    }

    /// Live master output VU meter
    private var masterMeter: some View {
        HStack(spacing: 3) {
            meterChannel(level: audioEngine.masterLevel, label: "L")
            meterChannel(level: audioEngine.masterLevelR, label: "R")
        }
    }

    private func meterChannel(level: Float, label: String) -> some View {
        VStack(spacing: 1) {
            // 12-segment LED meter
            ForEach((0..<12).reversed(), id: \.self) { i in
                let threshold = Float(i) / 12.0
                let isLit = level > threshold
                RoundedRectangle(cornerRadius: 1)
                    .fill(segmentColor(index: i))
                    .frame(width: 14, height: 3)
                    .opacity(isLit ? 1.0 : 0.15)
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(EchoelBrand.textTertiary)
        }
    }

    private func segmentColor(index: Int) -> Color {
        if index >= 10 { return EchoelBrand.coral } // red
        if index >= 7 { return EchoelBrand.amber } // yellow
        return EchoelBrand.emerald // green
    }

    // MARK: - Instrument Browser

    private var instrumentBrowserOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) { showInstrumentBrowser = false }
                }

            VStack(spacing: EchoelSpacing.md) {
                HStack {
                    Text("ADD TRACK")
                        .font(EchoelBrandFont.sectionTitle())
                        .foregroundColor(EchoelBrand.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) { showInstrumentBrowser = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                }

                ScrollView {
                    VStack(spacing: EchoelSpacing.md) {
                        trackTypeCategory("Audio", types: [
                            ("mic.fill", "Voice", Track.TrackType.voice),
                            ("waveform", "Audio", Track.TrackType.audio),
                        ])
                        trackTypeCategory("Instruments", types: [
                            ("pianokeys", "Instrument", Track.TrackType.instrument),
                            ("music.note", "MIDI", Track.TrackType.midi),
                        ])
                        trackTypeCategory("Routing", types: [
                            ("arrow.triangle.branch", "Aux/Return", Track.TrackType.aux),
                            ("rectangle.3.group", "Bus", Track.TrackType.bus),
                        ])
                    }
                }
            }
            .padding(EchoelSpacing.lg)
            .frame(maxWidth: 400, maxHeight: 500)
            .modifier(GlassCard())
        }
    }

    private func trackTypeCategory(_ title: String, types: [(String, String, Track.TrackType)]) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            Text(title.uppercased())
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.sky)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: EchoelSpacing.sm) {
                ForEach(types, id: \.1) { icon, name, type in
                    Button {
                        addTrack(name: name, type: type)
                        withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) { showInstrumentBrowser = false }
                    } label: {
                        VStack(spacing: EchoelSpacing.xs) {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(EchoelBrand.violet)
                            Text(name)
                                .font(EchoelBrandFont.caption())
                                .foregroundColor(EchoelBrand.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(EchoelSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(EchoelBrand.bgDeep.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(EchoelBrand.violet.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func addNewTrack() {
        withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) { showInstrumentBrowser = true }
    }

    private func addTrack(name: String, type: Track.TrackType) {
        guard var session = recordingEngine.currentSession else { return }
        let track = Track(name: "\(name) \(session.tracks.count + 1)", type: type)
        session.addTrack(track)
        recordingEngine.currentSession = session
    }

    private func togglePlayback() {
        if isPlaying {
            recordingEngine.stopPlayback()
            audioEngine.stop()
        } else {
            audioEngine.start()
            try? recordingEngine.startPlayback()
        }
        HapticHelper.impact(.medium)
    }

    private func toggleRecording() {
        if isRecording {
            try? recordingEngine.stopRecording()
            HapticHelper.notification(.success)
        } else {
            audioEngine.start()
            try? recordingEngine.startRecording()
            HapticHelper.impact(.heavy)
        }
    }

    // MARK: - Helpers

    private func toolbarButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: EchoelSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(EchoelBrandFont.caption())
            }
            .foregroundColor(isActive ? EchoelBrand.sky : EchoelBrand.textSecondary)
            .padding(.horizontal, EchoelSpacing.sm)
            .padding(.vertical, EchoelSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? EchoelBrand.sky.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(EchoelBrand.textSecondary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private func miniButton(label: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? EchoelBrand.bgDeep : EchoelBrand.textTertiary)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? color : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func formatPosition(_ time: TimeInterval) -> String {
        let bar = Int(time * bpm / 240.0) + 1
        let beatInBar = Int((time * bpm / 60.0).truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar).\(beatInBar)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func color(for trackColor: TrackColor) -> Color {
        switch trackColor {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return EchoelBrand.sky
        case .blue: return .blue
        case .purple: return EchoelBrand.violet
        case .pink: return EchoelBrand.coral
        case .magenta: return Color(red: 1, green: 0, blue: 1)
        case .teal: return .teal
        case .lime: return Color(red: 0.5, green: 1, blue: 0)
        case .amber: return Color(red: 1, green: 0.75, blue: 0)
        case .indigo: return .indigo
        case .rose: return Color(red: 1, green: 0.4, blue: 0.6)
        }
    }
}

// MARK: - Waveform Shape

/// Draws an audio waveform from sample data as a filled shape (center-mirrored)
struct WaveformShape: Shape {
    let samples: [Float]

    func path(in rect: CGRect) -> Path {
        guard !samples.isEmpty else { return Path() }

        var path = Path()
        let midY = rect.midY
        let count = samples.count
        let stepX = rect.width / CGFloat(count)

        // Top half (positive)
        path.move(to: CGPoint(x: 0, y: midY))
        for i in 0..<count {
            let x = CGFloat(i) * stepX
            let amplitude = CGFloat(min(samples[i], 1.0)) * (rect.height / 2)
            path.addLine(to: CGPoint(x: x, y: midY - amplitude))
        }

        // Bottom half (mirrored, going backwards)
        for i in stride(from: count - 1, through: 0, by: -1) {
            let x = CGFloat(i) * stepX
            let amplitude = CGFloat(min(samples[i], 1.0)) * (rect.height / 2)
            path.addLine(to: CGPoint(x: x, y: midY + amplitude))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Real Mixer Sheet

struct RealMixerSheet: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var recordingEngine: RecordingEngine
    @Environment(\.dismiss) private var dismiss

    private var tracks: [Track] {
        recordingEngine.currentSession?.tracks ?? []
    }

    var body: some View {
        ZStack {
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            VStack(spacing: EchoelSpacing.md) {
                HStack {
                    Text("MIXER")
                        .font(EchoelBrandFont.sectionTitle())
                        .foregroundColor(EchoelBrand.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                }
                .padding(.horizontal, EchoelSpacing.md)

                ScrollView(.horizontal) {
                    HStack(spacing: EchoelSpacing.md) {
                        ForEach(tracks) { track in
                            realChannelStrip(track: track)
                        }
                        masterChannelStrip()
                    }
                    .padding(EchoelSpacing.md)
                }
            }
        }
    }

    private func realChannelStrip(track: Track) -> some View {
        let trackColor = DAWArrangementView.staticColor(for: track.trackColor)

        return VStack(spacing: EchoelSpacing.sm) {
            Text(track.name)
                .font(EchoelBrandFont.caption())
                .foregroundColor(trackColor)
                .lineLimit(1)

            // VU Meter (uses track volume as simulated level for now)
            VStack(spacing: 2) {
                ForEach((0..<12).reversed(), id: \.self) { i in
                    let threshold = Float(i) / 12.0
                    let level = track.isMuted ? Float(0) : track.volume
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i > 8 ? EchoelBrand.coral : (i > 5 ? EchoelBrand.amber : EchoelBrand.emerald))
                        .frame(width: 40, height: 4)
                        .opacity(level > threshold ? 1.0 : 0.15)
                }
            }
            .padding(.vertical, EchoelSpacing.sm)

            // Volume fader
            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { Double(track.volume) },
                        set: { recordingEngine.setTrackVolume(track.id, volume: Float($0)) }
                    ),
                    in: 0...1
                )
                .tint(trackColor)
                .frame(height: 100)
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 40)

                Text(String(format: "%.1f dB", 20 * log10(max(track.volume, 0.001))))
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundColor(EchoelBrand.textSecondary)
            }

            // Pan knob display
            Text(panLabel(track.pan))
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.textSecondary)

            // M/S buttons
            HStack(spacing: 4) {
                Button {
                    recordingEngine.setTrackMuted(track.id, muted: !track.isMuted)
                } label: {
                    Text("M")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isMuted ? EchoelBrand.bgDeep : EchoelBrand.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 4).fill(track.isMuted ? EchoelBrand.coral : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(EchoelBrand.coral.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    recordingEngine.setTrackSoloed(track.id, soloed: !track.isSoloed)
                } label: {
                    Text("S")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isSoloed ? EchoelBrand.bgDeep : EchoelBrand.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 4).fill(track.isSoloed ? EchoelBrand.sky : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(EchoelBrand.sky.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 60)
        .padding(EchoelSpacing.sm)
        .modifier(GlassCard())
    }

    private func masterChannelStrip() -> some View {
        VStack(spacing: EchoelSpacing.sm) {
            Text("MASTER")
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.coral)

            // Live stereo meter
            HStack(spacing: 3) {
                liveMeterBar(level: audioEngine.masterLevel)
                liveMeterBar(level: audioEngine.masterLevelR)
            }
            .padding(.vertical, EchoelSpacing.sm)

            // Master fader
            Slider(
                value: Binding(
                    get: { Double(audioEngine.masterVolume) },
                    set: { audioEngine.masterVolume = Float($0) }
                ),
                in: 0...1
            )
            .tint(EchoelBrand.coral)
            .frame(height: 100)
            .rotationEffect(.degrees(-90))
            .frame(width: 100, height: 40)

            Text(String(format: "%.1f dB", 20 * log10(max(audioEngine.masterVolume, 0.001))))
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .frame(width: 80)
        .padding(EchoelSpacing.sm)
        .modifier(GlassCard())
    }

    private func liveMeterBar(level: Float) -> some View {
        VStack(spacing: 2) {
            ForEach((0..<12).reversed(), id: \.self) { i in
                let threshold = Float(i) / 12.0
                RoundedRectangle(cornerRadius: 1)
                    .fill(i > 8 ? EchoelBrand.coral : (i > 5 ? EchoelBrand.amber : EchoelBrand.emerald))
                    .frame(width: 16, height: 4)
                    .opacity(level > threshold ? 1.0 : 0.15)
            }
        }
    }

    private func panLabel(_ pan: Float) -> String {
        if abs(pan) < 0.05 { return "C" }
        if pan < 0 { return "L\(Int(abs(pan) * 100))" }
        return "R\(Int(pan * 100))"
    }
}

// MARK: - Static Helpers (for use in other views)

extension DAWArrangementView {
    static func staticColor(for trackColor: TrackColor) -> Color {
        switch trackColor {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return EchoelBrand.sky
        case .blue: return .blue
        case .purple: return EchoelBrand.violet
        case .pink: return EchoelBrand.coral
        case .magenta: return Color(red: 1, green: 0, blue: 1)
        case .teal: return .teal
        case .lime: return Color(red: 0.5, green: 1, blue: 0)
        case .amber: return Color(red: 1, green: 0.75, blue: 0)
        case .indigo: return .indigo
        case .rose: return Color(red: 1, green: 0.4, blue: 0.6)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DAWArrangementView()
        .environmentObject(AudioEngine())
        .environmentObject(RecordingEngine())
}
#endif
