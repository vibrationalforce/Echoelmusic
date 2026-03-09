#if canImport(SwiftUI)
import SwiftUI
import Accelerate

// MARK: - DAW Arrangement View
// Professional DAW arrangement with REAL audio engine integration

struct DAWArrangementView: View {
    @Environment(AudioEngine.self) var audioEngine
    @Environment(RecordingEngine.self) var recordingEngine
    @Bindable private var workspace = EchoelCreativeWorkspace.shared

    @State private var metronome = MetronomeEngine()

    @State private var selectedTrackID: UUID?
    @State private var timelineZoom: Double = 1.0
    @State private var showMixer = false
    @State private var showInstrumentBrowser = false
    @State private var showTrackList = true
    @State private var showSessionClips = false
    @State private var showEffectsChain = false
    @State private var showMasterExport = false
    @State private var showTempoEditor = false
    @State private var showMiniMixer = false
    @State private var automationTrackIDs: Set<UUID> = []
    @State private var showAddAutomation = false
    @State private var addAutomationTrackID: UUID?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var trackListWidth: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 140 : 180
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

    private var bpm: Double { max(workspace.globalBPM, 20.0) }
    private var isPlaying: Bool { workspace.isPlaying }
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
                if showMiniMixer {
                    miniMixerStrip
                }
            }

            if showInstrumentBrowser {
                instrumentBrowserOverlay
            }
        }
        .sheet(isPresented: $showMixer) {
            RealMixerSheet()
                .environment(audioEngine)
                .environment(recordingEngine)
        }
        .sheet(isPresented: $showSessionClips) {
            SessionClipView()
                .environment(audioEngine)
                .environment(recordingEngine)
        }
        .sheet(isPresented: $showEffectsChain) {
            DAWEffectsChainSheet()
                .environment(audioEngine)
                .environment(recordingEngine)
        }
        .sheet(isPresented: $showMasterExport) {
            MasterExportSheet()
                .environment(recordingEngine)
        }
        .sheet(isPresented: $showAddAutomation) {
            AutomationParameterPicker { parameter in
                if let trackID = addAutomationTrackID {
                    addAutomationLane(trackID: trackID, parameter: parameter)
                    automationTrackIDs.insert(trackID)
                }
            }
            .presentationDetents([.medium])
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
                    .accessibilityLabel("Play/Pause")
                    .accessibilityHint("Press Space to toggle playback")
                Button { toggleRecording(); HapticHelper.impact(.heavy) } label: { EmptyView() }
                    .keyboardShortcut("r", modifiers: [])
                    .accessibilityLabel("Record")
                    .accessibilityHint("Press R to toggle recording")
                Button { recordingEngine.undo(); HapticHelper.impact(.light) } label: { EmptyView() }
                    .keyboardShortcut("z", modifiers: .command)
                    .accessibilityLabel("Undo")
                    .accessibilityHint("Press Command+Z to undo")
                Button { recordingEngine.redo(); HapticHelper.impact(.light) } label: { EmptyView() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .accessibilityLabel("Redo")
                    .accessibilityHint("Press Command+Shift+Z to redo")
                Button { showMixer = true } label: { EmptyView() }
                    .keyboardShortcut("m", modifiers: .command)
                    .accessibilityLabel("Open Mixer")
                    .accessibilityHint("Press Command+M to open mixer")
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
        VStack(spacing: EchoelSpacing.xs) {
            // Row 1: BPM + tempo controls + toolbar
            HStack(spacing: EchoelSpacing.sm) {
                // BPM display with tempo controls
                HStack(spacing: EchoelSpacing.xs) {
                    // Metronome toggle
                    Button {
                        if metronome.isRunning {
                            metronome.stop()
                        } else {
                            metronome.setTempo(bpm)
                            metronome.start()
                        }
                        HapticHelper.impact(.light)
                    } label: {
                        Image(systemName: metronome.isRunning ? "metronome.fill" : "metronome")
                            .font(.system(size: 14))
                            .foregroundColor(metronome.isRunning ? EchoelBrand.coral : EchoelBrand.textSecondary)
                            .opacity(metronome.beatFlash ? 1.0 : 0.7)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    // Tempo down
                    Button {
                        let newBPM = max(40, workspace.globalBPM - 1)
                        workspace.globalBPM = newBPM
                        metronome.setTempo(newBPM)
                        HapticHelper.impact(.light)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(EchoelBrand.textTertiary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(EchoelBrand.bgElevated))
                    }
                    .buttonStyle(.plain)

                    // BPM value — tap for editor
                    Button {
                        showTempoEditor.toggle()
                    } label: {
                        HStack(spacing: EchoelSpacing.xs) {
                            Text("\(Int(bpm))")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(EchoelBrand.textPrimary)
                            Text("BPM")
                                .font(EchoelBrandFont.label())
                                .foregroundColor(EchoelBrand.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    // Tempo up
                    Button {
                        let newBPM = min(300, workspace.globalBPM + 1)
                        workspace.globalBPM = newBPM
                        metronome.setTempo(newBPM)
                        HapticHelper.impact(.light)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(EchoelBrand.textTertiary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(EchoelBrand.bgElevated))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, EchoelSpacing.sm)
                .padding(.vertical, EchoelSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(metronome.isRunning ? EchoelBrand.coral.opacity(0.1) : Color.clear)
                )
                .modifier(GlassCard())
                .popover(isPresented: $showTempoEditor) {
                    tempoEditorPopover
                }

                Spacer()

                // Toolbar icons
                HStack(spacing: isCompact ? EchoelSpacing.xs : EchoelSpacing.sm) {
                    if isCompact {
                        toolbarButton(icon: "sidebar.left", label: "Tracks", isActive: showTrackList) {
                            withAnimation(.easeInOut(duration: 0.2)) { showTrackList.toggle() }
                        }
                    }
                    toolbarButton(icon: "slider.horizontal.3", label: "Mix", isActive: showMiniMixer) {
                        withAnimation(.easeInOut(duration: 0.2)) { showMiniMixer.toggle() }
                    }
                    toolbarButton(icon: "square.and.arrow.up", label: "Export", isActive: false) {
                        showMasterExport = true
                    }
                    toolbarButton(icon: "line.3.crossed.swirl.circle", label: "Auto", isActive: !automationTrackIDs.isEmpty) {
                        // Toggle automation for selected track
                        if let id = selectedTrackID {
                            if automationTrackIDs.contains(id) {
                                automationTrackIDs.remove(id)
                            } else {
                                automationTrackIDs.insert(id)
                                if let track = tracks.first(where: { $0.id == id }), track.automationLanes.isEmpty {
                                    addAutomationLane(trackID: id, parameter: .volume)
                                }
                            }
                        }
                    }
                    toolbarButton(icon: "plus.circle", label: "Add", isActive: false) {
                        addNewTrack()
                    }
                }
            }
        }
        .padding(.horizontal, EchoelSpacing.sm)
        .padding(.vertical, EchoelSpacing.xs)
    }

    // MARK: - Tempo Editor Popover

    private var tempoEditorPopover: some View {
        VStack(spacing: EchoelSpacing.md) {
            Text("TEMPO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(1.5)

            Text("\(Int(workspace.globalBPM))")
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(EchoelBrand.textPrimary)

            Slider(
                value: $workspace.globalBPM,
                in: 40...300,
                step: 1
            ) {
                Text("BPM")
            }
            .tint(EchoelBrand.primary)
            .onChange(of: workspace.globalBPM) { _, newValue in
                metronome.setTempo(newValue)
            }

            // Quick presets
            HStack(spacing: EchoelSpacing.sm) {
                ForEach([80, 100, 120, 140, 160], id: \.self) { preset in
                    Button {
                        workspace.globalBPM = Double(preset)
                        metronome.setTempo(Double(preset))
                        HapticHelper.impact(.light)
                    } label: {
                        Text("\(preset)")
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundColor(
                                Int(workspace.globalBPM) == preset ? EchoelBrand.bgDeep : EchoelBrand.textSecondary
                            )
                            .frame(width: 44, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .fill(
                                        Int(workspace.globalBPM) == preset
                                            ? EchoelBrand.primary
                                            : EchoelBrand.bgElevated
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(EchoelSpacing.lg)
        .frame(width: 280)
        .background(EchoelBrand.bgSurface)
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

                    // Video track entry
                    videoTrackRow
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
                    .font(.system(size: isCompact ? 13 : 16, weight: .regular))
                    .foregroundColor(EchoelBrand.textPrimary)
                    .lineLimit(1)
                Text(track.type.rawValue)
                    .font(.system(size: isCompact ? 10 : 13))
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
                AutomationToggleButton(isShowing: automationTrackIDs.contains(track.id)) {
                    if automationTrackIDs.contains(track.id) {
                        automationTrackIDs.remove(track.id)
                    } else {
                        automationTrackIDs.insert(track.id)
                        // Add default volume lane if none exist
                        if track.automationLanes.isEmpty {
                            addAutomationLane(trackID: track.id, parameter: .volume)
                        }
                    }
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
        .contextMenu {
            Button {
                recordingEngine.setTrackMuted(track.id, muted: !track.isMuted)
            } label: {
                Label(track.isMuted ? "Unmute" : "Mute", systemImage: track.isMuted ? "speaker.wave.2" : "speaker.slash")
            }
            Button {
                recordingEngine.setTrackSoloed(track.id, soloed: !track.isSoloed)
            } label: {
                Label(track.isSoloed ? "Unsolo" : "Solo", systemImage: "headphones")
            }
            Divider()
            Button {
                if automationTrackIDs.contains(track.id) {
                    automationTrackIDs.remove(track.id)
                } else {
                    automationTrackIDs.insert(track.id)
                    if track.automationLanes.isEmpty {
                        addAutomationLane(trackID: track.id, parameter: .volume)
                    }
                }
            } label: {
                Label(automationTrackIDs.contains(track.id) ? "Hide Automation" : "Show Automation",
                      systemImage: "line.3.crossed.swirl.circle")
            }
            Button {
                addAutomationTrackID = track.id
                showAddAutomation = true
            } label: {
                Label("Add Automation Lane", systemImage: "plus.circle")
            }
            Divider()
            Button(role: .destructive) {
                try? recordingEngine.deleteTrack(track.id)
                if selectedTrackID == track.id {
                    selectedTrackID = nil
                }
            } label: {
                Label("Delete Track", systemImage: "trash")
            }
        }
    }

    // MARK: - Video Track Row (Track List)

    private var videoTrackRow: some View {
        let videoColor = EchoelBrand.coral
        let clipCount = workspace.videoEditor.videoClips.count

        return HStack(spacing: EchoelSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(videoColor)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Video")
                    .font(.system(size: isCompact ? 13 : 16, weight: .regular))
                    .foregroundColor(EchoelBrand.textPrimary)
                    .lineLimit(1)
                Text(clipCount > 0 ? "\(clipCount) clips" : "No clips")
                    .font(.system(size: isCompact ? 10 : 13))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "film")
                .font(.system(size: 12))
                .foregroundColor(videoColor.opacity(0.6))
        }
        .padding(EchoelSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(videoColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(videoColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Arrangement Timeline

    private var arrangementSection: some View {
        VStack(spacing: 0) {
            timelineRuler

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Beat grid lines
                    beatGridOverlay

                    // Track lanes
                    VStack(spacing: EchoelSpacing.xs) {
                        ForEach(tracks) { track in
                            VStack(spacing: 0) {
                                trackLane(track: track)

                                // Automation lanes below track
                                if automationTrackIDs.contains(track.id) {
                                    ForEach(track.automationLanes.filter(\.isVisible)) { lane in
                                        AutomationLaneView(
                                            track: track,
                                            lane: lane,
                                            pixelsPerSecond: pixelsPerSecond,
                                            totalDuration: Swift.max(track.duration, 30),
                                            onUpdatePoint: { trackID, laneID, time, value in
                                                updateAutomationPoint(trackID: trackID, laneID: laneID, time: time, value: value)
                                            },
                                            onAddPoint: { trackID, laneID, time, value in
                                                addAutomationPoint(trackID: trackID, laneID: laneID, time: time, value: value)
                                            },
                                            onDeletePoint: { trackID, laneID, pointID in
                                                deleteAutomationPoint(trackID: trackID, laneID: laneID, pointID: pointID)
                                            }
                                        )
                                    }

                                    // Add lane button
                                    Button {
                                        addAutomationTrackID = track.id
                                        showAddAutomation = true
                                    } label: {
                                        HStack(spacing: EchoelSpacing.xs) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 9))
                                            Text("Add Lane")
                                                .font(.system(size: 9, weight: .medium))
                                        }
                                        .foregroundColor(EchoelBrand.textTertiary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, EchoelSpacing.sm)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Video track (BPM-synced with audio)
                        videoTrackLane

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
                let safeBpm = max(bpm, 20.0)
                let totalBars = max(16, Int(ceil((recordingEngine.currentSession?.duration ?? 30) * safeBpm / 240.0)) + 4)
                let barWidth = (240.0 / safeBpm) * pixelsPerSecond // 4 beats per bar

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
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let time = max(0, Double(value.location.x) / pixelsPerSecond)
                    recordingEngine.seek(to: time)
                }
        )
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

    // MARK: - Video Track Lane

    private var videoTrackLane: some View {
        let videoClips = workspace.videoEditor.videoClips
        let laneWidth = max(300, CGFloat(workspace.videoEditor.duration) * pixelsPerSecond + 20)
        let videoColor = EchoelBrand.coral

        return ZStack(alignment: .leading) {
            // Lane background
            RoundedRectangle(cornerRadius: 4)
                .fill(videoColor.opacity(0.05))
                .frame(width: laneWidth, height: 60)

            // Video clip regions
            ForEach(videoClips) { clip in
                let clipStart = CGFloat(clip.startTime) * pixelsPerSecond
                let clipDuration = CGFloat(clip.duration) * pixelsPerSecond

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(videoColor.opacity(0.25))
                        .frame(width: max(20, clipDuration), height: 56)

                    // Film strip pattern
                    HStack(spacing: 2) {
                        ForEach(0..<max(1, Int(clipDuration / 12)), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(videoColor.opacity(0.15))
                                .frame(width: 8, height: 40)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(videoColor.opacity(0.5), lineWidth: 1)
                        .frame(width: max(20, clipDuration), height: 56)

                    Text(clip.name)
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        .frame(width: max(20, clipDuration), alignment: .leading)
                        .offset(y: -20)
                }
                .offset(x: clipStart)
            }

            // Empty state
            if videoClips.isEmpty {
                HStack(spacing: EchoelSpacing.xs) {
                    Image(systemName: "film")
                        .font(.system(size: 12))
                        .foregroundColor(videoColor.opacity(0.4))
                    Text("Drop video or use Video panel")
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textTertiary)
                }
                .padding(.leading, EchoelSpacing.sm)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(videoColor.opacity(0.15), lineWidth: 0.5)
        )
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

    // MARK: - Beat Grid Overlay

    private var beatGridOverlay: some View {
        let beatWidth = (60.0 / max(bpm, 20.0)) * pixelsPerSecond
        let barWidth = beatWidth * 4
        let totalBars = max(16, Int(ceil((recordingEngine.currentSession?.duration ?? 30) * bpm / 240.0)) + 4)
        let laneHeight = CGFloat(max(tracks.count, 1) + 1) * 64 + CGFloat(EchoelSpacing.sm * 2) // +1 for video track

        return Canvas { context, size in
            for bar in 0..<totalBars {
                let barX = CGFloat(bar) * barWidth + CGFloat(EchoelSpacing.sm)

                // Bar line (strong)
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: barX, y: 0))
                        p.addLine(to: CGPoint(x: barX, y: laneHeight))
                    },
                    with: .color(Color.white.opacity(bar % 4 == 0 ? 0.12 : 0.06)),
                    lineWidth: bar % 4 == 0 ? 1 : 0.5
                )

                // Beat lines within bar (lighter)
                if timelineZoom > 0.5 {
                    for beat in 1..<4 {
                        let beatX = barX + CGFloat(beat) * beatWidth
                        context.stroke(
                            Path { p in
                                p.move(to: CGPoint(x: beatX, y: 0))
                                p.addLine(to: CGPoint(x: beatX, y: laneHeight))
                            },
                            with: .color(Color.white.opacity(0.03)),
                            lineWidth: 0.5
                        )
                    }
                }
            }
        }
        .frame(
            width: CGFloat(totalBars) * barWidth + CGFloat(EchoelSpacing.sm * 2),
            height: laneHeight
        )
        .allowsHitTesting(false)
    }

    // MARK: - Mini Mixer Strip (FL Mobile Style)

    private var miniMixerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EchoelSpacing.xs) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    VStack(spacing: EchoelSpacing.xs) {
                        // Track name
                        Text(track.name.prefix(4).uppercased())
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(EchoelBrand.textSecondary)
                            .lineLimit(1)

                        // Volume slider (vertical)
                        GeometryReader { geo in
                            let height = geo.size.height
                            let volume = CGFloat(track.volume)

                            ZStack(alignment: .bottom) {
                                // Track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(EchoelBrand.bgDeep)
                                    .frame(width: 6)

                                // Fill
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(track.isMuted ? EchoelBrand.textTertiary : EchoelBrand.sky)
                                    .frame(width: 6, height: height * volume)
                            }
                            .frame(maxWidth: .infinity)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newVol = Float(1.0 - (value.location.y / height))
                                        recordingEngine.setTrackVolume(track.id, volume: max(0, min(1, newVol)))
                                    }
                            )
                        }
                        .frame(width: 24, height: 60)

                        // Mute button
                        Button {
                            recordingEngine.setTrackMuted(track.id, muted: !track.isMuted)
                            HapticHelper.impact(.light)
                        } label: {
                            Text("M")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(track.isMuted ? EchoelBrand.bgDeep : EchoelBrand.textTertiary)
                                .frame(width: 18, height: 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(track.isMuted ? EchoelBrand.amber : EchoelBrand.bgElevated)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 32)
                }

                // Master fader
                VStack(spacing: EchoelSpacing.xs) {
                    Text("MST")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(EchoelBrand.emerald)
                        .lineLimit(1)

                    // Master level indicator
                    GeometryReader { geo in
                        let height = geo.size.height
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(EchoelBrand.bgDeep)
                                .frame(width: 8)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(EchoelBrand.emerald)
                                .frame(width: 8, height: height * CGFloat(audioEngine.masterLevel))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: 28, height: 60)

                    // Master label
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(EchoelBrand.emerald)
                        .frame(width: 18, height: 14)
                }
                .frame(width: 36)
            }
            .padding(.horizontal, EchoelSpacing.sm)
        }
        .frame(height: 100)
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
        EchoelCreativeWorkspace.shared.togglePlayback()
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

    // MARK: - Automation Helpers

    private func addAutomationLane(trackID: UUID, parameter: AutomatedParameter) {
        guard var session = recordingEngine.currentSession,
              let trackIdx = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }
        // Don't add duplicate parameter lanes
        guard !session.tracks[trackIdx].automationLanes.contains(where: { $0.parameter == parameter }) else { return }
        let lane = TrackAutomationLane(parameter: parameter)
        session.tracks[trackIdx].automationLanes.append(lane)
        recordingEngine.currentSession = session
    }

    private func addAutomationPoint(trackID: UUID, laneID: UUID, time: TimeInterval, value: Float) {
        guard var session = recordingEngine.currentSession,
              let trackIdx = session.tracks.firstIndex(where: { $0.id == trackID }),
              let laneIdx = session.tracks[trackIdx].automationLanes.firstIndex(where: { $0.id == laneID }) else { return }
        let point = TrackAutomationPoint(time: time, value: value)
        session.tracks[trackIdx].automationLanes[laneIdx].points.append(point)
        session.tracks[trackIdx].automationLanes[laneIdx].points.sort { $0.time < $1.time }
        recordingEngine.currentSession = session
    }

    private func updateAutomationPoint(trackID: UUID, laneID: UUID, time: TimeInterval, value: Float) {
        guard var session = recordingEngine.currentSession,
              let trackIdx = session.tracks.firstIndex(where: { $0.id == trackID }),
              let laneIdx = session.tracks[trackIdx].automationLanes.firstIndex(where: { $0.id == laneID }),
              let pointIdx = session.tracks[trackIdx].automationLanes[laneIdx].points.indices.last else { return }
        session.tracks[trackIdx].automationLanes[laneIdx].points[pointIdx].time = time
        session.tracks[trackIdx].automationLanes[laneIdx].points[pointIdx].value = value
        session.tracks[trackIdx].automationLanes[laneIdx].points.sort { $0.time < $1.time }
        recordingEngine.currentSession = session
    }

    private func deleteAutomationPoint(trackID: UUID, laneID: UUID, pointID: UUID) {
        guard var session = recordingEngine.currentSession,
              let trackIdx = session.tracks.firstIndex(where: { $0.id == trackID }),
              let laneIdx = session.tracks[trackIdx].automationLanes.firstIndex(where: { $0.id == laneID }) else { return }
        session.tracks[trackIdx].automationLanes[laneIdx].points.removeAll { $0.id == pointID }
        recordingEngine.currentSession = session
    }

    // MARK: - Helpers

    private func toolbarButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 16 : 20))
                if !isCompact {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isActive ? EchoelBrand.sky : EchoelBrand.textSecondary)
            .frame(width: isCompact ? 36 : 52, height: isCompact ? 36 : 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? EchoelBrand.sky.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniButton(label: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticHelper.impact(.light)
        } label: {
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

// MARK: - DAW Effects Chain Sheet

struct DAWEffectsChainSheet: View {
    @State private var nodeGraph = NodeGraph()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            EffectsChainView(nodeGraph: nodeGraph)
                .background(EchoelBrand.bgDeep.ignoresSafeArea())
                .navigationTitle("Effects Chain")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundColor(EchoelBrand.primary)
                    }
                }
        }
        .onAppear {
            if nodeGraph.nodes.isEmpty {
                nodeGraph.loadFromPreset(NodeGraph.createProductionChain())
            }
        }
    }
}

// MARK: - Master Export Sheet

struct MasterExportSheet: View {
    @Environment(RecordingEngine.self) var recordingEngine
    private let exportManager = ExportManager()
    @Environment(\.dismiss) private var dismiss

    enum MasterFormat: String, CaseIterable {
        case wav24_441 = "WAV 24-bit / 44.1 kHz"
        case wav24_48 = "WAV 24-bit / 48 kHz"
        case wav16_441 = "WAV 16-bit / 44.1 kHz (CD)"
        case aiff24 = "AIFF 24-bit / 44.1 kHz"
        case m4a = "AAC (M4A) / 48 kHz"

        var format: ExportManager.ExportFormat {
            switch self {
            case .wav24_441, .wav24_48, .wav16_441: return .wav
            case .aiff24: return .aiff
            case .m4a: return .m4a
            }
        }

        var displayDescription: String {
            switch self {
            case .wav24_441: return "Industry standard for music distribution"
            case .wav24_48: return "Studio quality, video post-production"
            case .wav16_441: return "Red Book CD standard"
            case .aiff24: return "Apple lossless, compatible with Logic Pro"
            case .m4a: return "Compressed, good for streaming previews"
            }
        }
    }

    @State private var selectedFormat: MasterFormat = .wav24_441
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: EchoelSpacing.lg) {
                    // Session info
                    sessionInfoCard

                    // Format selection
                    formatSection

                    // Progress
                    if isExporting {
                        progressSection
                    }

                    // Error
                    if let error = exportError {
                        Text(error)
                            .font(EchoelBrandFont.caption())
                            .foregroundColor(EchoelBrand.coral)
                            .padding(EchoelSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .fill(EchoelBrand.coral.opacity(0.1))
                            )
                    }

                    // Success
                    if exportSuccess {
                        HStack(spacing: EchoelSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(EchoelBrand.emerald)
                            Text("Master exported successfully")
                                .font(EchoelBrandFont.body())
                                .foregroundColor(EchoelBrand.emerald)
                        }
                        .padding(EchoelSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                .fill(EchoelBrand.emerald.opacity(0.1))
                        )
                    }

                    Spacer(minLength: EchoelSpacing.lg)

                    // Export button
                    Button {
                        Task { await performMasterExport() }
                    } label: {
                        HStack(spacing: EchoelSpacing.sm) {
                            if isExporting {
                                ProgressView()
                                    .tint(EchoelBrand.bgDeep)
                            } else {
                                Image(systemName: "waveform.badge.arrow.down")
                            }
                            Text(isExporting ? "Mastering..." : "Export Master")
                                .fontWeight(.semibold)
                        }
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.bgDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EchoelSpacing.md)
                        .background(
                            Capsule()
                                .fill(isExporting ? EchoelBrand.textTertiary : EchoelBrand.primary)
                        )
                    }
                    .disabled(isExporting)
                    .buttonStyle(.plain)
                }
                .padding(EchoelSpacing.lg)
            }
            .background(EchoelBrand.bgDeep.ignoresSafeArea())
            .navigationTitle("Master Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EchoelBrand.primary)
                }
            }
        }
    }

    private var sessionInfoCard: some View {
        let session = recordingEngine.currentSession

        return VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: "music.note.list")
                    .foregroundColor(EchoelBrand.sky)
                Text("SESSION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(1.5)
            }

            if let session = session {
                HStack {
                    VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                        Text(session.name)
                            .font(EchoelBrandFont.cardTitle())
                            .foregroundColor(EchoelBrand.textPrimary)
                        Text("\(session.tracks.count) tracks")
                            .font(EchoelBrandFont.caption())
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: EchoelSpacing.xs) {
                        Text(formatDuration(session.duration))
                            .font(EchoelBrandFont.data())
                            .foregroundColor(EchoelBrand.textPrimary)
                        Text("duration")
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.textTertiary)
                    }
                }
            } else {
                Text("No session loaded")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textTertiary)
            }
        }
        .padding(EchoelSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .fill(EchoelBrand.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .stroke(EchoelBrand.border, lineWidth: 1)
        )
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: "waveform")
                    .foregroundColor(EchoelBrand.textSecondary)
                Text("MASTER FORMAT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(1.5)
            }

            ForEach(MasterFormat.allCases, id: \.self) { format in
                Button {
                    selectedFormat = format
                    HapticHelper.impact(.light)
                } label: {
                    HStack(spacing: EchoelSpacing.md) {
                        ZStack {
                            Circle()
                                .stroke(
                                    selectedFormat == format ? EchoelBrand.primary : EchoelBrand.border,
                                    lineWidth: 2
                                )
                                .frame(width: 20, height: 20)

                            if selectedFormat == format {
                                Circle()
                                    .fill(EchoelBrand.primary)
                                    .frame(width: 10, height: 10)
                            }
                        }

                        VStack(alignment: .leading, spacing: EchoelSpacing.xxs) {
                            Text(format.rawValue)
                                .font(EchoelBrandFont.body())
                                .foregroundColor(
                                    selectedFormat == format ? EchoelBrand.textPrimary : EchoelBrand.textSecondary
                                )
                            Text(format.displayDescription)
                                .font(EchoelBrandFont.caption())
                                .foregroundColor(EchoelBrand.textTertiary)
                        }

                        Spacer()

                        if format == .wav24_441 {
                            Text("REC")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(EchoelBrand.emerald)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(EchoelBrand.emerald.opacity(0.15))
                                )
                        }
                    }
                    .padding(EchoelSpacing.sm + EchoelSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(selectedFormat == format ? EchoelBrand.primary.opacity(0.06) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .stroke(
                                selectedFormat == format ? EchoelBrand.borderActive : EchoelBrand.border,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: EchoelSpacing.sm) {
            ProgressView()
                .tint(EchoelBrand.sky)
            Text("Rendering master...")
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(EchoelSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                .fill(EchoelBrand.bgSurface)
        )
    }

    private func performMasterExport() async {
        guard let session = recordingEngine.currentSession else {
            exportError = "No session loaded"
            return
        }

        isExporting = true
        exportError = nil
        exportSuccess = false

        do {
            let url = try await exportManager.exportAudio(
                session: session,
                format: selectedFormat.format
            )
            isExporting = false
            exportSuccess = true
            HapticHelper.notification(.success)

            // Share the exported file
            #if os(iOS)
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            #endif
        } catch {
            isExporting = false
            exportError = "Export failed: \(error.localizedDescription)"
            HapticHelper.notification(.error)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Real Mixer Sheet

struct RealMixerSheet: View {
    @Environment(AudioEngine.self) var audioEngine
    @Environment(RecordingEngine.self) var recordingEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isEmbeddedInPanel) private var isEmbeddedInPanel

    private var tracks: [Track] {
        recordingEngine.currentSession?.tracks ?? []
    }

    var body: some View {
        ZStack {
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            VStack(spacing: isEmbeddedInPanel ? EchoelSpacing.sm : EchoelSpacing.md) {
                // Header — skip when embedded in panel (panel has its own)
                if !isEmbeddedInPanel {
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
                }

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

            // LUFS meter (broadcast loudness)
            LUFSMeterView(levelL: audioEngine.masterLevel, levelR: audioEngine.masterLevelR)

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
        .environment(AudioEngine())
        .environment(RecordingEngine())
}
#endif
#endif
