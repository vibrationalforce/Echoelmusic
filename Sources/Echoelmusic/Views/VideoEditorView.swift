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
            EchoelBrand.bgDeep
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
                    HStack(spacing: EchoelSpacing.md) {
                        previewSection

                        if showEffectsPanel {
                            effectsPanel
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, EchoelSpacing.md)

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
            VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                Text("VIDEO EDITOR")
                    .font(EchoelBrandFont.sectionTitle())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text("DAW + Video")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)
            }

            Spacer()

            Spacer()

            // Toolbar buttons
            HStack(spacing: EchoelSpacing.sm) {
                toolbarButton(icon: "metronome", label: "BPM", isActive: showBPMGrid) {
                    withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                        showBPMGrid.toggle()
                    }
                }

                toolbarButton(icon: "square.stack.3d.up", label: "Effects", isActive: showEffectsPanel) {
                    withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                        showEffectsPanel.toggle()
                    }
                }

                #if os(iOS)
                toolbarButton(icon: "camera.fill", label: "Capture", isActive: showCameraCapture) {
                    withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
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
        .padding(EchoelSpacing.md)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: EchoelSpacing.sm) {
            // Video Preview Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(EchoelBrand.bgDeep)

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
                                    .fill(EchoelBrand.sky)
                                    .frame(width: CGFloat(cameraAnalyzer.filterModulation) * 40, height: 6)
                                    .animation(.easeOut(duration: 0.1), value: cameraAnalyzer.filterModulation)
                            }
                            .foregroundColor(EchoelBrand.sky)
                        }
                        .padding(EchoelSpacing.sm)

                        Spacer()

                        // BPM suggestion (bottom of camera preview)
                        if cameraAnalyzer.isPulseDetecting && cameraAnalyzer.estimatedBPM > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(EchoelBrand.coral)
                                    .font(.system(size: 12))
                                Text("\(Int(cameraAnalyzer.estimatedBPM)) BPM")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(EchoelBrand.coral)

                                // Apply BPM button
                                Button {
                                    workspace.setGlobalBPM(cameraAnalyzer.estimatedBPM)
                                    HapticHelper.notification(.success)
                                } label: {
                                    Text("Apply")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(EchoelBrand.bgDeep)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(EchoelBrand.coral))
                                }
                                .buttonStyle(.plain)

                                // Confidence bar
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(EchoelBrand.coral.opacity(cameraAnalyzer.bpmConfidence))
                                    .frame(width: 30, height: 4)
                            }
                            .padding(.horizontal, EchoelSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(EchoelBrand.bgDeep.opacity(0.7))
                            )
                            .padding(.bottom, EchoelSpacing.sm)
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
                                .foregroundColor(cameraAnalyzer.isPulseDetecting ? EchoelBrand.coral : EchoelBrand.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(cameraAnalyzer.isPulseDetecting ? EchoelBrand.coral.opacity(0.15) : EchoelBrand.bgDeep.opacity(0.5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, EchoelSpacing.sm)
                        .padding(.bottom, EchoelSpacing.sm)
                    }
                } else if let player = videoPlayer {
                    // Real AVPlayer video preview
                    VideoPlayerView(player: player)
                        .cornerRadius(12)
                } else if engine.currentProject != nil {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(EchoelBrand.textTertiary)
                } else {
                    VStack(spacing: EchoelSpacing.md) {
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
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundColor(EchoelBrand.textPrimary)
                            .padding(.horizontal, EchoelSpacing.sm)
                            .padding(.vertical, EchoelSpacing.xs)
                            .background(
                                Capsule()
                                    .fill(EchoelBrand.bgDeep.opacity(0.8))
                            )
                        Spacer()
                    }
                    .padding(EchoelSpacing.sm)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .modifier(GlassCard())

            // Preview metrics
            HStack(spacing: EchoelSpacing.lg) {
                metricDisplay(value: "1920x1080", label: "Resolution", color: EchoelBrand.sky)
                metricDisplay(value: "30 fps", label: "Frame Rate", color: EchoelBrand.violet)
                metricDisplay(value: formatDuration(engine.duration), label: "Duration", color: EchoelBrand.coral)
            }
        }
    }

    // MARK: - Effects Panel

    private var effectsPanel: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            Text("EFFECTS")
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(2)

            ScrollView {
                VStack(spacing: EchoelSpacing.sm) {
                    effectCategory("Color", effects: ["Auto Color", "LUT", "Color Grade", "HDR"])
                    effectCategory("Style", effects: ["Cinematic", "Vintage", "Neon Glow", "Glitch"])
                    effectCategory("Bio-Reactive", effects: ["Coherence Pulse", "Heart Sync", "Breath Flow"])
                    effectCategory("AI", effects: ["Style Transfer", "Face Enhance", "Background Remove"])
                }
            }
        }
        .frame(width: 250)
        .padding(EchoelSpacing.md)
        .modifier(GlassCard())
    }

    private func effectCategory(_ title: String, effects: [String]) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
            Text(title.uppercased())
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.sky)

            ForEach(effects, id: \.self) { effect in
                Button {
                    // Apply effect
                } label: {
                    HStack {
                        Text(effect)
                            .font(EchoelBrandFont.body())
                            .foregroundColor(EchoelBrand.textPrimary)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(EchoelBrand.textTertiary)
                    }
                    .padding(.vertical, EchoelSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EchoelSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(EchoelBrand.bgDeep.opacity(0.5))
        )
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(spacing: EchoelSpacing.sm) {
            // Timeline header with BPM controls
            HStack {
                Text("TIMELINE")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textSecondary)
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
                HStack(spacing: EchoelSpacing.xs) {
                    Button { timelineZoom = max(0.5, timelineZoom - 0.25) } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(EchoelBrand.textSecondary)
                    }

                    Text("\(Int(timelineZoom * 100))%")
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textTertiary)
                        .frame(width: 50)

                    Button { timelineZoom = min(4.0, timelineZoom + 0.25) } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                }
            }
            .padding(.horizontal, EchoelSpacing.md)

            // Timeline tracks with beat grid overlay
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .leading) {
                    // Beat grid markers (behind tracks)
                    if showBPMGrid {
                        beatGridOverlay
                    }

                    VStack(spacing: EchoelSpacing.xs) {
                        // Video track
                        timelineTrack(name: "Video", color: EchoelBrand.sky, clips: engine.videoClips)

                        // Audio track
                        timelineTrack(name: "Audio", color: EchoelBrand.violet, clips: engine.audioClips)

                        // Bio track
                        timelineTrack(name: "Bio-Sync", color: EchoelBrand.coral, clips: [])
                    }
                }
                .padding(.horizontal, EchoelSpacing.md)
            }
            .frame(height: 150)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        timelineZoom = max(0.5, min(4.0, value))
                    }
            )
            .modifier(GlassCard())
            .padding(.horizontal, EchoelSpacing.md)
        }
    }

    // MARK: - BPM Grid Controls

    private var bpmGridControls: some View {
        HStack(spacing: EchoelSpacing.sm) {
            // BPM display + tap tempo
            Button {
                // Tap tempo — record tap times for BPM detection
                workspace.bpmGrid.tapTempo()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 12))
                    Text("\(Int(workspace.globalBPM))")
                        .font(EchoelBrandFont.dataSmall())
                    Text("BPM")
                        .font(EchoelBrandFont.label())
                }
                .foregroundColor(EchoelBrand.coral)
                .padding(.horizontal, EchoelSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(EchoelBrand.coral.opacity(0.15))
                        .overlay(Capsule().stroke(EchoelBrand.coral.opacity(0.4), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            // BPM adjust buttons
            HStack(spacing: 2) {
                Button { workspace.setGlobalBPM(workspace.globalBPM - 1) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)

                Button { workspace.setGlobalBPM(workspace.globalBPM + 1) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(EchoelBrand.textSecondary)
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
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.sky)
                    .padding(.horizontal, EchoelSpacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(EchoelBrand.sky.opacity(0.1))
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
                    .font(EchoelBrandFont.caption())
            }
            .foregroundColor(workspace.bpmGrid.snapMode != .off ? EchoelBrand.sky : EchoelBrand.textTertiary)
            .padding(.horizontal, EchoelSpacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(workspace.bpmGrid.snapMode != .off ? EchoelBrand.sky.opacity(0.1) : Color.clear)
            )
        }
        .padding(.trailing, EchoelSpacing.sm)
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
                    .fill(isBar ? EchoelBrand.coral.opacity(0.3) : EchoelBrand.textTertiary.opacity(0.15))
                    .frame(width: isBar ? 1.5 : 0.5, height: geometry.size.height)
                    .offset(x: x)
            }
        }
    }

    private func timelineTrack(name: String, color: Color, clips: [EditorVideoClip]) -> some View {
        HStack(spacing: 0) {
            // Track label
            Text(name)
                .font(EchoelBrandFont.caption())
                .foregroundColor(color)
                .frame(width: 70, alignment: .leading)

            // Track content
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(EchoelBrand.bgDeep.opacity(0.5))
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
                    .fill(EchoelBrand.coral)
                    .frame(width: 2)
                    .offset(x: CGFloat(currentTime * 10 * timelineZoom))
                    .modifier(NeonGlow(color: EchoelBrand.coral, radius: 5))
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
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            )
            .modifier(isSelected ? NeonGlow(color: color, radius: 8) : NeonGlow(color: .clear, radius: 0))
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: EchoelSpacing.lg) {
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
                        .fill(EchoelBrand.coral.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Circle()
                        .stroke(EchoelBrand.coral, lineWidth: 2)
                        .frame(width: 60, height: 60)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(EchoelBrand.coral)
                }
                .modifier(NeonGlow(color: EchoelBrand.coral, radius: isPlaying ? 15 : 8))
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
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.coral)
                    Text("Beat \(position.beat)")
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textSecondary)
                }
                .padding(.horizontal, EchoelSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(EchoelBrand.bgDeep.opacity(0.6))
                )
            }
        }
        .padding(EchoelSpacing.md)
    }

    // MARK: - Helper Views

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
                .font(.system(size: 20))
                .foregroundColor(EchoelBrand.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func metricDisplay(value: String, label: String, color: Color) -> some View {
        VStack(spacing: EchoelSpacing.xs) {
            Text(value)
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(color)
            Text(label)
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textTertiary)
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
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            VStack(spacing: EchoelSpacing.lg) {
                // Header
                HStack {
                    Text("EXPORT VIDEO")
                        .font(EchoelBrandFont.sectionTitle())
                        .foregroundColor(EchoelBrand.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                }

                // Settings
                VStack(spacing: EchoelSpacing.md) {
                    exportSetting(title: "Format", value: $selectedFormat, options: ["H.264", "H.265", "ProRes"])
                    exportSetting(title: "Resolution", value: $selectedResolution, options: ["720p", "1080p", "4K"])
                    exportSetting(title: "Quality", value: $selectedQuality, options: ["Draft", "Good", "High", "Best"])
                }
                .modifier(GlassCard())

                // Progress
                if exportManager.isExporting {
                    VStack(spacing: EchoelSpacing.sm) {
                        ProgressView(value: exportManager.exportProgress)
                            .tint(EchoelBrand.sky)
                        Text("\(Int(exportManager.exportProgress * 100))%")
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                    .padding()
                    .modifier(GlassCard())
                }

                if let error = exportError {
                    Text(error)
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.coral)
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
                                .tint(EchoelBrand.bgDeep)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(exportManager.isExporting ? "Exporting..." : "Export")
                    }
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.bgDeep)
                    .padding(.horizontal, EchoelSpacing.xl)
                    .padding(.vertical, EchoelSpacing.md)
                    .background(
                        Capsule()
                            .fill(exportManager.isExporting ? EchoelBrand.textTertiary : EchoelBrand.sky)
                    )
                    .modifier(NeonGlow(color: EchoelBrand.sky, radius: 15))
                }
                .disabled(exportManager.isExporting)
            }
            .padding(EchoelSpacing.lg)
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
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.textSecondary)

            Spacer()

            Picker(title, selection: value) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(EchoelBrand.sky)
        }
        .padding(EchoelSpacing.sm)
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
                        .background(EchoelBrand.sky.opacity(0.2))
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
