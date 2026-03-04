import SwiftUI
import AVFoundation
import PhotosUI
#if canImport(Metal)
import Metal
#endif

// MARK: - Video Editor View
// Professional Video Editor with Camera Capture, Import, AVPlayer Preview

/// Professional video editing interface
@MainActor
struct VideoEditorView: View {
    @StateObject private var engine = VideoEditingEngine()
    @StateObject private var cameraAnalyzer = CameraAnalyzer()
    @State private var cameraManager: CameraManager?
    @ObservedObject private var workspace = EchoelCreativeWorkspace.shared
    @State private var selectedClipIndex: Int?
    @State private var timelineZoom: Double = 1.0
    @State private var showEffectsPanel = false
    @State private var showExportSheet = false
    @State private var showBPMGrid = true
    @State private var showCameraCapture = false
    @State private var currentTime: TimeInterval = 0
    @State private var isPlaying = false
    @State private var showVideoPicker = false
    @State private var videoPlayer: AVPlayer?
    @State private var importProgress: String?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Whether on iPhone compact layout
    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            // Background
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                if isCompact {
                    // iPhone: stacked layout (preview on top, timeline below)
                    VStack(spacing: 0) {
                        previewSection
                            .frame(maxHeight: 200)

                        timelineSection

                        transportControls
                    }
                } else {
                    // iPad/Mac: side-by-side layout
                    HStack(spacing: VaporwaveSpacing.md) {
                        previewSection

                        if showEffectsPanel {
                            effectsPanel
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, VaporwaveSpacing.md)

                    timelineSection

                    transportControls
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            VideoExportSheet(engine: engine)
        }
        .sheet(isPresented: $showVideoPicker) {
            if #available(iOS 16.0, *) {
                VideoPickerSheet(engine: engine, videoPlayer: $videoPlayer, currentTime: $currentTime, importProgress: $importProgress)
            } else {
                Text("Video import requires iOS 16+")
                    .foregroundColor(.secondary)
            }
        }
        .onDisappear {
            // Clean up camera and audio resources
            cameraManager?.stopCapture()
            cameraAnalyzer.reset()
            videoPlayer?.pause()
            videoPlayer = nil
        }
        // Keyboard shortcuts
        .background(
            Group {
                Button {
                    workspace.togglePlayback()
                    isPlaying = workspace.isPlaying
                    HapticHelper.impact(.medium)
                } label: { EmptyView() }
                    .keyboardShortcut(.space, modifiers: [])
                Button { showExportSheet = true } label: { EmptyView() }
                    .keyboardShortcut("e", modifiers: .command)
                Button { showVideoPicker = true } label: { EmptyView() }
                    .keyboardShortcut("i", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("VIDEO EDITOR")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("DAW + Video")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }

            Spacer()

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

                #if os(iOS)
                toolbarButton(icon: "camera.fill", label: "Capture", isActive: showCameraCapture) {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showCameraCapture.toggle()
                        if showCameraCapture {
                            Task {
                                if cameraManager == nil, let device = MTLCreateSystemDefaultDevice() {
                                    cameraManager = CameraManager(device: device)
                                }
                                // Wire camera frames to analyzer
                                cameraManager?.onRawFrameCaptured = { [weak cameraAnalyzer] pixelBuffer, _ in
                                    cameraAnalyzer?.analyzePixelBuffer(pixelBuffer)
                                }
                                try? await cameraManager?.startCapture()
                            }
                        } else {
                            cameraManager?.stopCapture()
                            cameraAnalyzer.reset()
                        }
                    }
                }
                #endif

                toolbarButton(icon: "square.and.arrow.up", label: "Export", isActive: false) {
                    showExportSheet = true
                }
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Video Preview Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(VaporwaveColors.deepBlack)

                // Preview content
                if showCameraCapture, let cam = cameraManager, cam.isCapturing {
                    // Live camera preview
                    #if os(iOS)
                    CameraPreviewLayer(cameraManager: cam)
                    #endif

                    // Camera analysis overlay (top)
                    VStack {
                        HStack {
                            Circle()
                                .fill(EchoelBrand.coherenceHigh)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(EchoelBrand.coherenceHigh)

                            Spacer()

                            // Filter modulation indicator
                            HStack(spacing: 4) {
                                Image(systemName: "camera.filters")
                                    .font(.system(size: 10))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VaporwaveColors.neonCyan)
                                    .frame(width: CGFloat(cameraAnalyzer.filterModulation) * 40, height: 6)
                                    .animation(.easeOut(duration: 0.1), value: cameraAnalyzer.filterModulation)
                            }
                            .foregroundColor(VaporwaveColors.neonCyan)
                        }
                        .padding(VaporwaveSpacing.sm)

                        Spacer()

                        // BPM suggestion (bottom of camera preview)
                        if cameraAnalyzer.isPulseDetecting && cameraAnalyzer.estimatedBPM > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(VaporwaveColors.neonPink)
                                    .font(.system(size: 12))
                                Text("\(Int(cameraAnalyzer.estimatedBPM)) BPM")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(VaporwaveColors.neonPink)

                                // Apply BPM button
                                Button {
                                    workspace.setGlobalBPM(cameraAnalyzer.estimatedBPM)
                                    HapticHelper.notification(.success)
                                } label: {
                                    Text("Apply")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(VaporwaveColors.deepBlack)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(VaporwaveColors.neonPink))
                                }
                                .buttonStyle(.plain)

                                // Confidence bar
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VaporwaveColors.neonPink.opacity(cameraAnalyzer.bpmConfidence))
                                    .frame(width: 30, height: 4)
                            }
                            .padding(.horizontal, VaporwaveSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(VaporwaveColors.deepBlack.opacity(0.7))
                            )
                            .padding(.bottom, VaporwaveSpacing.sm)
                        }

                        // Pulse detection toggle
                        HStack {
                            Spacer()
                            Button {
                                cameraAnalyzer.togglePulseDetection()
                                HapticHelper.impact(.light)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cameraAnalyzer.isPulseDetecting ? "heart.fill" : "heart")
                                        .font(.system(size: 11))
                                    Text(cameraAnalyzer.isPulseDetecting ? "Pulse ON" : "Pulse")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(cameraAnalyzer.isPulseDetecting ? VaporwaveColors.neonPink : VaporwaveColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(cameraAnalyzer.isPulseDetecting ? VaporwaveColors.neonPink.opacity(0.15) : VaporwaveColors.deepBlack.opacity(0.5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, VaporwaveSpacing.sm)
                        .padding(.bottom, VaporwaveSpacing.sm)
                    }
                } else if let player = videoPlayer {
                    // Real AVPlayer video preview
                    VideoPlayerView(player: player)
                        .cornerRadius(12)
                } else if engine.currentProject != nil {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(VaporwaveColors.textTertiary)
                } else {
                    VStack(spacing: VaporwaveSpacing.md) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(EchoelBrand.primary)
                            .modifier(EchoelGlow(color: EchoelBrand.primary, radius: 10))

                        Text("Import or Capture Video")
                            .font(EchoelBrandFont.body())
                            .foregroundColor(EchoelBrand.textSecondary)

                        HStack(spacing: EchoelSpacing.md) {
                            // Import video from library
                            Button { showVideoPicker = true } label: {
                                HStack(spacing: EchoelSpacing.sm) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("Import Video")
                                }
                                .font(EchoelBrandFont.body().weight(.medium))
                                .foregroundColor(EchoelBrand.bgDeep)
                                .padding(.horizontal, EchoelSpacing.lg)
                                .padding(.vertical, EchoelSpacing.md)
                                .background(Capsule().fill(EchoelBrand.primary))
                            }
                            .buttonStyle(.plain)

                            #if os(iOS)
                            // Open camera
                            Button {
                                showCameraCapture = true
                                Task {
                                    if cameraManager == nil, let device = MTLCreateSystemDefaultDevice() {
                                        cameraManager = CameraManager(device: device)
                                    }
                                    cameraManager?.onRawFrameCaptured = { [weak cameraAnalyzer] pixelBuffer, _ in
                                        cameraAnalyzer?.analyzePixelBuffer(pixelBuffer)
                                    }
                                    try? await cameraManager?.startCapture()
                                }
                            } label: {
                                HStack(spacing: EchoelSpacing.sm) {
                                    Image(systemName: "camera.fill")
                                    Text("Camera")
                                }
                                .font(EchoelBrandFont.body().weight(.medium))
                                .foregroundColor(EchoelBrand.textPrimary)
                                .padding(.horizontal, EchoelSpacing.lg)
                                .padding(.vertical, EchoelSpacing.md)
                                .background(
                                    Capsule()
                                        .stroke(EchoelBrand.primary, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
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
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        timelineZoom = max(0.5, min(4.0, value))
                    }
            )
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
            Spacer()

            // Beat-snap cut (previous beat)
            if showBPMGrid {
                transportButton(icon: "scissors") {
                    // Snap to nearest beat
                    let beatDuration = 60.0 / workspace.globalBPM
                    currentTime = round(currentTime / beatDuration) * beatDuration
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
                HapticHelper.impact(.medium)
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
    @StateObject private var exportManager = VideoExportManager()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = "H.264"
    @State private var selectedResolution = "1080p"
    @State private var selectedQuality = "High"
    @State private var exportError: String?

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
                    exportSetting(title: "Format", value: $selectedFormat, options: ["H.264", "H.265", "ProRes"])
                    exportSetting(title: "Resolution", value: $selectedResolution, options: ["720p", "1080p", "4K"])
                    exportSetting(title: "Quality", value: $selectedQuality, options: ["Draft", "Good", "High", "Best"])
                }
                .modifier(GlassCard())

                // Progress
                if exportManager.isExporting {
                    VStack(spacing: VaporwaveSpacing.sm) {
                        ProgressView(value: exportManager.exportProgress)
                            .tint(VaporwaveColors.neonCyan)
                        Text("\(Int(exportManager.exportProgress * 100))%")
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                    .padding()
                    .modifier(GlassCard())
                }

                if let error = exportError {
                    Text(error)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.coral)
                        .padding()
                }

                Spacer()

                // Export button
                Button {
                    Task { await performExport() }
                } label: {
                    HStack {
                        if exportManager.isExporting {
                            ProgressView()
                                .tint(VaporwaveColors.deepBlack)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(exportManager.isExporting ? "Exporting..." : "Export")
                    }
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .padding(.horizontal, VaporwaveSpacing.xl)
                    .padding(.vertical, VaporwaveSpacing.md)
                    .background(
                        Capsule()
                            .fill(exportManager.isExporting ? VaporwaveColors.textTertiary : VaporwaveColors.neonCyan)
                    )
                    .modifier(NeonGlow(color: VaporwaveColors.neonCyan, radius: 15))
                }
                .disabled(exportManager.isExporting)
            }
            .padding(VaporwaveSpacing.lg)
        }
    }

    private func performExport() async {
        exportError = nil
        guard let composition = try? await engine.buildComposition() else {
            exportError = "No video content to export"
            return
        }

        // Map UI selections to ExportManager types
        let format: VideoExportManager.ExportFormat = {
            switch selectedFormat {
            case "H.265": return .hevc_main
            case "ProRes": return .prores422
            default: return .h264_high
            }
        }()

        let resolution: VideoExportManager.Resolution = {
            switch selectedResolution {
            case "720p": return .hd1280x720
            case "4K": return .uhd3840x2160
            default: return .hd1920x1080
            }
        }()

        let quality: VideoExportManager.Quality = {
            switch selectedQuality {
            case "Draft": return .low
            case "Good": return .medium
            case "Best": return .maximum
            default: return .high
            }
        }()

        // Generate output URL
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let outputURL = documentsDir
            .appendingPathComponent("Echoelmusic_Export_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension(format.fileExtension)

        do {
            try await exportManager.export(
                composition: composition,
                to: outputURL,
                format: format,
                resolution: resolution,
                quality: quality
            )
            HapticHelper.notification(.success)
            dismiss()
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
            HapticHelper.notification(.error)
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

// MARK: - Video Picker Sheet (iOS 16+)

@available(iOS 16.0, *)
struct VideoPickerSheet: View {
    @ObservedObject var engine: VideoEditingEngine
    @Binding var videoPlayer: AVPlayer?
    @Binding var currentTime: TimeInterval
    @Binding var importProgress: String?
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let progress = importProgress {
                    ProgressView(progress)
                        .padding()
                }

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .videos
                ) {
                    Label("Select Videos", systemImage: "film.stack")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(VaporwaveColors.neonCyan.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Import Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItems) { _ in
                Task {
                    await importSelectedVideos()
                    dismiss()
                }
            }
        }
    }

    private func importSelectedVideos() async {
        for item in selectedItems {
            importProgress = "Importing..."
            guard let movie = try? await item.loadTransferable(type: VideoTransferable.self) else {
                continue
            }

            let asset = AVAsset(url: movie.url)
            let duration = (try? await asset.load(.duration)) ?? CMTime.zero
            let durationSeconds = CMTimeGetSeconds(duration)
            guard durationSeconds > 0 else { continue }

            let clip = VideoClip(
                name: "Clip \(engine.timeline.videoTracks.first?.clips.count ?? 0 + 1)",
                asset: asset,
                startTime: CMTime(seconds: currentTime, preferredTimescale: 600),
                duration: duration,
                inPoint: .zero,
                outPoint: duration
            )

            if let videoTrack = engine.timeline.videoTracks.first {
                engine.addClip(clip, to: videoTrack, at: clip.startTime)
            }

            let playerItem = AVPlayerItem(asset: asset)
            if videoPlayer == nil {
                videoPlayer = AVPlayer(playerItem: playerItem)
            } else {
                videoPlayer?.replaceCurrentItem(with: playerItem)
            }

            currentTime += durationSeconds
        }
        importProgress = nil
    }
}

/// Transferable for importing videos from PhotosPicker
@available(iOS 16.0, macOS 13.0, *)
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "\(UUID().uuidString).mov"
            let destination = tempDir.appendingPathComponent(filename)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

// MARK: - AVPlayer SwiftUI Wrapper

#if os(iOS)
import UIKit

/// UIViewRepresentable wrapper for AVPlayerLayer — shows video playback
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerView = uiView as? PlayerUIView {
            playerView.playerLayer.player = player
        }
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#else
/// macOS stub
struct VideoPlayerView: View {
    let player: AVPlayer
    var body: some View {
        Text("Video Preview")
            .foregroundColor(.secondary)
    }
}
#endif

// MARK: - Camera Preview Layer (UIViewRepresentable)

#if os(iOS)
/// SwiftUI wrapper for AVCaptureVideoPreviewLayer — shows live camera feed.
struct CameraPreviewLayer: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
#endif

// MARK: - Preview

#if DEBUG
#Preview {
    VideoEditorView()
}
#endif
