import SwiftUI

// MARK: - Video Editor View
// Homogeneous GUI with VaporwaveTheme - "Flüssiges Licht"

/// Professional video editing interface with bio-reactive features
@MainActor
struct VideoEditorView: View {
    @StateObject private var engine = VideoEditingEngine()
    @StateObject private var workspace = EchoelCreativeWorkspace.shared
    @State private var selectedClipIndex: Int?
    @State private var timelineZoom: Double = 1.0
    @State private var showEffectsPanel = false
    @State private var showExportSheet = false
    @State private var showBPMGrid = true
    @State private var currentTime: TimeInterval = 0
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            // Background
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                // Preview + Effects
                HStack(spacing: VaporwaveSpacing.md) {
                    // Video Preview
                    previewSection

                    // Effects Panel (conditional)
                    if showEffectsPanel {
                        effectsPanel
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, VaporwaveSpacing.md)

                // Timeline
                timelineSection

                // Transport Controls
                transportControls
            }
        }
        .sheet(isPresented: $showExportSheet) {
            VideoExportSheet(engine: engine)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("VIDEO EDITOR")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(workspace.mode.rawValue)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }

            Spacer()

            // Workspace mode switcher
            workspaceModePicker

            Spacer()

            // Toolbar buttons
            HStack(spacing: VaporwaveSpacing.sm) {
                toolbarButton(icon: "metronome", label: "BPM", isActive: showBPMGrid) {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showBPMGrid.toggle()
                    }
                }

                toolbarButton(icon: "square.stack.3d.up", label: "Effects", isActive: showEffectsPanel) {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showEffectsPanel.toggle()
                    }
                }

                toolbarButton(icon: "square.and.arrow.up", label: "Export", isActive: false) {
                    showExportSheet = true
                }
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Workspace Mode Picker

    private var workspaceModePicker: some View {
        HStack(spacing: VaporwaveSpacing.xs) {
            ForEach(WorkspaceMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(VaporwaveAnimation.smooth) {
                        workspace.switchMode(mode)
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14))
                        Text(mode.rawValue)
                            .font(VaporwaveTypography.label())
                    }
                    .foregroundColor(workspace.mode == mode ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                    .padding(.horizontal, VaporwaveSpacing.sm)
                    .padding(.vertical, VaporwaveSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(workspace.mode == mode ? VaporwaveColors.neonCyan.opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Video Preview Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(VaporwaveColors.deepBlack)

                // Preview content
                if let _ = engine.currentProject {
                    // Video preview would render here
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(VaporwaveColors.textTertiary)
                } else {
                    VStack(spacing: VaporwaveSpacing.md) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .modifier(NeonGlow(color: VaporwaveColors.neonCyan, radius: 10))

                        Text("Import Video")
                            .font(VaporwaveTypography.body())
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }

                // Timecode overlay
                VStack {
                    Spacer()
                    HStack {
                        Text(formatTimecode(currentTime))
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(VaporwaveColors.textPrimary)
                            .padding(.horizontal, VaporwaveSpacing.sm)
                            .padding(.vertical, VaporwaveSpacing.xs)
                            .background(
                                Capsule()
                                    .fill(VaporwaveColors.deepBlack.opacity(0.8))
                            )
                        Spacer()
                    }
                    .padding(VaporwaveSpacing.sm)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .modifier(GlassCard())

            // Preview metrics
            HStack(spacing: VaporwaveSpacing.lg) {
                metricDisplay(value: "1920x1080", label: "Resolution", color: VaporwaveColors.neonCyan)
                metricDisplay(value: "30 fps", label: "Frame Rate", color: VaporwaveColors.neonPurple)
                metricDisplay(value: formatDuration(engine.duration), label: "Duration", color: VaporwaveColors.neonPink)
            }
        }
    }

    // MARK: - Effects Panel

    private var effectsPanel: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            Text("EFFECTS")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textSecondary)
                .tracking(2)

            ScrollView {
                VStack(spacing: VaporwaveSpacing.sm) {
                    effectCategory("Color", effects: ["Auto Color", "LUT", "Color Grade", "HDR"])
                    effectCategory("Style", effects: ["Cinematic", "Vintage", "Neon Glow", "Glitch"])
                    effectCategory("Bio-Reactive", effects: ["Coherence Pulse", "Heart Sync", "Breath Flow"])
                    effectCategory("AI", effects: ["Style Transfer", "Face Enhance", "Background Remove"])
                }
            }
        }
        .frame(width: 250)
        .padding(VaporwaveSpacing.md)
        .modifier(GlassCard())
    }

    private func effectCategory(_ title: String, effects: [String]) -> some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
            Text(title.uppercased())
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.neonCyan)

            ForEach(effects, id: \.self) { effect in
                Button {
                    // Apply effect
                } label: {
                    HStack {
                        Text(effect)
                            .font(VaporwaveTypography.body())
                            .foregroundColor(VaporwaveColors.textPrimary)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                    .padding(.vertical, VaporwaveSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VaporwaveSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VaporwaveColors.deepBlack.opacity(0.5))
        )
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Timeline header with BPM controls
            HStack {
                Text("TIMELINE")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .tracking(2)

                // BPM Grid controls (inline)
                if showBPMGrid {
                    bpmGridControls
                }

                Spacer()

                // Snap mode selector
                if showBPMGrid {
                    snapModeSelector
                }

                // Zoom control
                HStack(spacing: VaporwaveSpacing.xs) {
                    Button { timelineZoom = max(0.5, timelineZoom - 0.25) } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }

                    Text("\(Int(timelineZoom * 100))%")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .frame(width: 50)

                    Button { timelineZoom = min(4.0, timelineZoom + 0.25) } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, VaporwaveSpacing.md)

            // Timeline tracks with beat grid overlay
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .leading) {
                    // Beat grid markers (behind tracks)
                    if showBPMGrid {
                        beatGridOverlay
                    }

                    VStack(spacing: VaporwaveSpacing.xs) {
                        // Video track
                        timelineTrack(name: "Video", color: VaporwaveColors.neonCyan, clips: engine.videoClips)

                        // Audio track
                        timelineTrack(name: "Audio", color: VaporwaveColors.neonPurple, clips: engine.audioClips)

                        // Bio track
                        timelineTrack(name: "Bio-Sync", color: VaporwaveColors.neonPink, clips: [])
                    }
                }
                .padding(.horizontal, VaporwaveSpacing.md)
            }
            .frame(height: 150)
            .modifier(GlassCard())
            .padding(.horizontal, VaporwaveSpacing.md)
        }
    }

    // MARK: - BPM Grid Controls

    private var bpmGridControls: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            // BPM display + tap tempo
            Button {
                // Tap tempo — record tap times for BPM detection
                workspace.bpmGrid.tapTempo()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 12))
                    Text("\(Int(workspace.globalBPM))")
                        .font(VaporwaveTypography.dataSmall())
                    Text("BPM")
                        .font(VaporwaveTypography.label())
                }
                .foregroundColor(VaporwaveColors.neonPink)
                .padding(.horizontal, VaporwaveSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(VaporwaveColors.neonPink.opacity(0.15))
                        .overlay(Capsule().stroke(VaporwaveColors.neonPink.opacity(0.4), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            // BPM adjust buttons
            HStack(spacing: 2) {
                Button { workspace.setGlobalBPM(workspace.globalBPM - 1) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VaporwaveColors.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)

                Button { workspace.setGlobalBPM(workspace.globalBPM + 1) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VaporwaveColors.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            // Time signature
            Menu {
                ForEach(TimeSignature.common, id: \.displayString) { ts in
                    Button(ts.displayString) {
                        workspace.setGlobalTimeSignature(ts)
                    }
                }
            } label: {
                Text(workspace.globalTimeSignature.displayString)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .padding(.horizontal, VaporwaveSpacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VaporwaveColors.neonCyan.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Snap Mode Selector

    private var snapModeSelector: some View {
        Menu {
            ForEach(SnapMode.allCases, id: \.self) { mode in
                Button {
                    workspace.bpmGrid.snapMode = mode
                } label: {
                    HStack {
                        Text(mode.rawValue)
                        if workspace.bpmGrid.snapMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "magnet")
                    .font(.system(size: 11))
                Text(workspace.bpmGrid.snapMode.rawValue)
                    .font(VaporwaveTypography.caption())
            }
            .foregroundColor(workspace.bpmGrid.snapMode != .off ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
            .padding(.horizontal, VaporwaveSpacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(workspace.bpmGrid.snapMode != .off ? VaporwaveColors.neonCyan.opacity(0.1) : Color.clear)
            )
        }
        .padding(.trailing, VaporwaveSpacing.sm)
    }

    // MARK: - Beat Grid Overlay

    private var beatGridOverlay: some View {
        GeometryReader { geometry in
            let bpm = workspace.globalBPM
            let beatsPerSecond = bpm / 60.0
            let pixelsPerSecond = 10.0 * timelineZoom
            let pixelsPerBeat = pixelsPerSecond / beatsPerSecond
            let beatsPerBar = Double(workspace.globalTimeSignature.beatsPerBar)
            let totalWidth = geometry.size.width
            let beatCount = Int(totalWidth / pixelsPerBeat) + 1

            ForEach(0..<beatCount, id: \.self) { beat in
                let x = Double(beat) * pixelsPerBeat + 70 // offset for track label
                let isBar = beat % Int(beatsPerBar) == 0

                Rectangle()
                    .fill(isBar ? VaporwaveColors.neonPink.opacity(0.3) : VaporwaveColors.textTertiary.opacity(0.15))
                    .frame(width: isBar ? 1.5 : 0.5, height: geometry.size.height)
                    .offset(x: x)
            }
        }
    }

    private func timelineTrack(name: String, color: Color, clips: [EditorVideoClip]) -> some View {
        HStack(spacing: 0) {
            // Track label
            Text(name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(color)
                .frame(width: 70, alignment: .leading)

            // Track content
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(VaporwaveColors.deepBlack.opacity(0.5))
                    .frame(height: 40)

                // Clips
                HStack(spacing: 2) {
                    ForEach(clips.indices, id: \.self) { index in
                        let clip = clips[index]
                        clipView(clip: clip, color: color, isSelected: selectedClipIndex == index)
                            .onTapGesture {
                                selectedClipIndex = index
                            }
                    }
                }
                .padding(.horizontal, 2)

                // Playhead
                Rectangle()
                    .fill(VaporwaveColors.neonPink)
                    .frame(width: 2)
                    .offset(x: CGFloat(currentTime * 10 * timelineZoom))
                    .modifier(NeonGlow(color: VaporwaveColors.neonPink, radius: 5))
            }
        }
    }

    private func clipView(clip: EditorVideoClip, color: Color, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(isSelected ? 0.6 : 0.3))
            .frame(width: CGFloat(clip.duration * 10 * timelineZoom), height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? color : color.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(
                Text(clip.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            )
            .modifier(isSelected ? NeonGlow(color: color, radius: 8) : NeonGlow(color: .clear, radius: 0))
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Output target selector
            Menu {
                ForEach(OutputTarget.allCases, id: \.self) { target in
                    Button {
                        workspace.outputTarget = target
                    } label: {
                        HStack {
                            Image(systemName: target.icon)
                            Text(target.rawValue)
                            if workspace.outputTarget == target {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: workspace.outputTarget.icon)
                        .font(.system(size: 12))
                    Text(workspace.outputTarget.rawValue)
                        .font(VaporwaveTypography.caption())
                }
                .foregroundColor(VaporwaveColors.neonPurple)
                .padding(.horizontal, VaporwaveSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(VaporwaveColors.neonPurple.opacity(0.1))
                )
            }

            Spacer()

            // Beat-snap cut (previous beat)
            if showBPMGrid {
                transportButton(icon: "scissors") {
                    currentTime = workspace.cutVideoOnBeat(at: currentTime)
                }
            }

            // Skip back
            transportButton(icon: "backward.fill") {
                currentTime = max(0, currentTime - 5)
            }

            // Previous beat
            if showBPMGrid {
                transportButton(icon: "backward.end.fill") {
                    let beatDuration = 60.0 / workspace.globalBPM
                    currentTime = max(0, currentTime - beatDuration)
                }
            }

            // Play/Pause
            Button {
                workspace.togglePlayback()
                isPlaying = workspace.isPlaying
            } label: {
                ZStack {
                    Circle()
                        .fill(VaporwaveColors.neonPink.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Circle()
                        .stroke(VaporwaveColors.neonPink, lineWidth: 2)
                        .frame(width: 60, height: 60)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(VaporwaveColors.neonPink)
                }
                .modifier(NeonGlow(color: VaporwaveColors.neonPink, radius: isPlaying ? 15 : 8))
            }
            .buttonStyle(.plain)

            // Next beat
            if showBPMGrid {
                transportButton(icon: "forward.end.fill") {
                    let beatDuration = 60.0 / workspace.globalBPM
                    currentTime += beatDuration
                }
            }

            // Skip forward
            transportButton(icon: "forward.fill") {
                currentTime += 5
            }

            Spacer()

            // Beat position display
            if showBPMGrid {
                let position = workspace.bpmGrid.grid.beatPosition(at: currentTime)
                HStack(spacing: 4) {
                    Text("Bar \(position.bar)")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.neonPink)
                    Text("Beat \(position.beat)")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
                .padding(.horizontal, VaporwaveSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(VaporwaveColors.deepBlack.opacity(0.6))
                )
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Helper Views

    private func toolbarButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(VaporwaveTypography.caption())
            }
            .foregroundColor(isActive ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
            .padding(.horizontal, VaporwaveSpacing.sm)
            .padding(.vertical, VaporwaveSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? VaporwaveColors.neonCyan.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(VaporwaveColors.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func metricDisplay(value: String, label: String, color: Color) -> some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            Text(value)
                .font(VaporwaveTypography.dataSmall())
                .foregroundColor(color)
            Text(label)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
    }

    // MARK: - Formatting

    private func formatTimecode(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * 30)
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Clip Model

struct EditorVideoClip: Identifiable {
    let id = UUID()
    var name: String
    var startTime: TimeInterval
    var duration: TimeInterval
    var effects: [String] = []
}

// MARK: - Video Export Sheet

struct VideoExportSheet: View {
    @ObservedObject var engine: VideoEditingEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = "H.264"
    @State private var selectedResolution = "1080p"
    @State private var selectedQuality = "High"

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.lg) {
                // Header
                HStack {
                    Text("EXPORT VIDEO")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }

                // Settings
                VStack(spacing: VaporwaveSpacing.md) {
                    exportSetting(title: "Format", value: $selectedFormat, options: ["H.264", "H.265", "ProRes", "AV1"])
                    exportSetting(title: "Resolution", value: $selectedResolution, options: ["720p", "1080p", "4K", "8K"])
                    exportSetting(title: "Quality", value: $selectedQuality, options: ["Draft", "Good", "High", "Best"])
                }
                .modifier(GlassCard())

                Spacer()

                // Export button
                Button {
                    // Export action
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .padding(.horizontal, VaporwaveSpacing.xl)
                    .padding(.vertical, VaporwaveSpacing.md)
                    .background(
                        Capsule()
                            .fill(VaporwaveColors.neonCyan)
                    )
                    .modifier(NeonGlow(color: VaporwaveColors.neonCyan, radius: 15))
                }
            }
            .padding(VaporwaveSpacing.lg)
        }
    }

    private func exportSetting(title: String, value: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(title)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            Picker(title, selection: value) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(VaporwaveColors.neonCyan)
        }
        .padding(VaporwaveSpacing.sm)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VideoEditorView()
}
#endif
