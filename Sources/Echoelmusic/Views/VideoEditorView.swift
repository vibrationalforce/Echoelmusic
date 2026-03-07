#if canImport(SwiftUI)
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
    @State private var engine = VideoEditingEngine()
    @State private var cameraAnalyzer = CameraAnalyzer()
    @State private var cameraManager: CameraManager?
    @Bindable private var workspace = EchoelCreativeWorkspace.shared
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

                        if showEffectsPanel {
                            quickEffectsStrip
                        }

                        timelineSection
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
                    .accessibilityLabel("Play/Pause")
                    .accessibilityHint("Press Space to toggle playback")
                Button { showExportSheet = true } label: { EmptyView() }
                    .keyboardShortcut("e", modifiers: .command)
                    .accessibilityLabel("Export")
                    .accessibilityHint("Press Command+E to export")
                Button { showVideoPicker = true } label: { EmptyView() }
                    .keyboardShortcut("i", modifiers: .command)
                    .accessibilityLabel("Import Video")
                    .accessibilityHint("Press Command+I to import video")
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

            if let progress = importProgress {
                HStack(spacing: EchoelSpacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(progress)
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textSecondary)
                }
                .transition(.opacity)
            }

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

    // MARK: - Quick Effects Strip (CapCut/InShot Style)

    private var quickEffectsStrip: some View {
        VStack(spacing: 0) {
            // Color grading sliders (DaVinci style)
            VStack(spacing: EchoelSpacing.xs) {
                colorSlider(label: "EXP", value: Binding(
                    get: { engine.currentGrade?.exposure ?? 0 },
                    set: { engine.applyLiveGrade(ColorGradeEffect(exposure: $0, contrast: engine.currentGrade?.contrast ?? 1, saturation: engine.currentGrade?.saturation ?? 1, temperature: engine.currentGrade?.temperature ?? 0, tint: engine.currentGrade?.tint ?? 0)) }
                ), range: -1...1, color: EchoelBrand.amber)

                colorSlider(label: "CON", value: Binding(
                    get: { (engine.currentGrade?.contrast ?? 1) - 1 },
                    set: { engine.applyLiveGrade(ColorGradeEffect(exposure: engine.currentGrade?.exposure ?? 0, contrast: $0 + 1, saturation: engine.currentGrade?.saturation ?? 1, temperature: engine.currentGrade?.temperature ?? 0, tint: engine.currentGrade?.tint ?? 0)) }
                ), range: -0.5...0.5, color: EchoelBrand.primary)

                colorSlider(label: "SAT", value: Binding(
                    get: { (engine.currentGrade?.saturation ?? 1) - 1 },
                    set: { engine.applyLiveGrade(ColorGradeEffect(exposure: engine.currentGrade?.exposure ?? 0, contrast: engine.currentGrade?.contrast ?? 1, saturation: $0 + 1, temperature: engine.currentGrade?.temperature ?? 0, tint: engine.currentGrade?.tint ?? 0)) }
                ), range: -0.5...0.5, color: EchoelBrand.coral)

                colorSlider(label: "TEMP", value: Binding(
                    get: { engine.currentGrade?.temperature ?? 0 },
                    set: { engine.applyLiveGrade(ColorGradeEffect(exposure: engine.currentGrade?.exposure ?? 0, contrast: engine.currentGrade?.contrast ?? 1, saturation: engine.currentGrade?.saturation ?? 1, temperature: $0, tint: engine.currentGrade?.tint ?? 0)) }
                ), range: -1...1, color: EchoelBrand.sky)
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.sm)

            // Quick filter presets (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EchoelSpacing.sm) {
                    quickFilterButton("Reset", icon: "arrow.counterclockwise", color: EchoelBrand.textSecondary) {
                        engine.applyLiveGrade(ColorGradeEffect())
                    }
                    quickFilterButton("Cinema", icon: "film", color: EchoelBrand.coral) {
                        applyVideoEffect("Cinematic")
                    }
                    quickFilterButton("Vintage", icon: "camera.filters", color: EchoelBrand.amber) {
                        applyVideoEffect("Vintage")
                    }
                    quickFilterButton("Neon", icon: "lightbulb.fill", color: EchoelBrand.violet) {
                        applyVideoEffect("Neon Glow")
                    }
                    quickFilterButton("HDR", icon: "sun.max.fill", color: EchoelBrand.sky) {
                        applyVideoEffect("HDR")
                    }
                    quickFilterButton("B&W", icon: "circle.lefthalf.filled", color: EchoelBrand.primary) {
                        applyVideoEffect("Heart Sync")
                    }
                    quickFilterButton("Warm", icon: "flame", color: EchoelBrand.coral) {
                        engine.applyLiveGrade(ColorGradeEffect(saturation: 1.1, temperature: 0.2))
                    }
                    quickFilterButton("Cool", icon: "snowflake", color: EchoelBrand.sky) {
                        engine.applyLiveGrade(ColorGradeEffect(saturation: 1.1, temperature: -0.2))
                    }
                }
                .padding(.horizontal, EchoelSpacing.md)
            }
            .padding(.bottom, EchoelSpacing.sm)
        }
        .background(EchoelBrand.bgSurface)
    }

    private func colorSlider(label: String, value: Binding<Float>, range: ClosedRange<Float>, color: Color) -> some View {
        HStack(spacing: EchoelSpacing.sm) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 32, alignment: .leading)

            Slider(value: value, in: range)
                .tint(color)

            Text(String(format: "%+.1f", value.wrappedValue))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
                .frame(width: 30, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func quickFilterButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticHelper.impact(.light)
        } label: {
            VStack(spacing: EchoelSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(color.opacity(0.1))
                    )

                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func effectCategory(_ title: String, effects: [String]) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
            Text(title.uppercased())
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.sky)

            ForEach(effects, id: \.self) { effect in
                Button {
                    applyVideoEffect(effect)
                    HapticHelper.impact(.light)
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

    // Order: exposure, contrast, saturation, temperature, tint
    private func applyVideoEffect(_ name: String) {
        switch name {
        // Color effects
        case "Auto Color":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.1, saturation: 1.15))
        case "LUT":
            engine.applyLiveGrade(ColorGradeEffect(saturation: 1.2, temperature: -0.1, tint: 0.05))
        case "Color Grade":
            engine.applyLiveGrade(ColorGradeEffect(exposure: 0.1, contrast: 1.15, temperature: 0.05))
        case "HDR":
            engine.applyLiveGrade(ColorGradeEffect(exposure: 0.15, contrast: 1.3, saturation: 1.1))

        // Style effects
        case "Cinematic":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.2, saturation: 0.85, temperature: 0.1))
        case "Vintage":
            engine.applyLiveGrade(ColorGradeEffect(exposure: -0.05, contrast: 0.9, saturation: 0.6, temperature: 0.15))
        case "Neon Glow":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.4, saturation: 1.5, temperature: -0.1))
        case "Glitch":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.3, saturation: 1.8, tint: 0.2))

        // Bio-Reactive
        case "Coherence Pulse":
            engine.applyLiveGrade(ColorGradeEffect(exposure: 0.1, saturation: 1.3, temperature: -0.05))
        case "Heart Sync":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.1, saturation: 1.1, temperature: 0.1))
        case "Breath Flow":
            engine.applyLiveGrade(ColorGradeEffect(exposure: 0.05, contrast: 1.05, saturation: 0.95))

        // AI effects
        case "Style Transfer":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.25, saturation: 1.2, temperature: -0.05))
        case "Face Enhance":
            engine.applyLiveGrade(ColorGradeEffect(exposure: 0.08, contrast: 1.05, saturation: 1.05))
        case "Background Remove":
            engine.applyLiveGrade(ColorGradeEffect(contrast: 1.15, saturation: 0.9))

        default:
            break
        }
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

    // MARK: - Helper Views

    private func toolbarButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticHelper.impact(.light)
        } label: {
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
    @Bindable var engine: VideoEditingEngine
    @State private var exportManager = VideoExportManager()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: VideoTemplate = .youtube1080
    @State private var exportError: String?
    @State private var exportSuccess = false

    // MARK: - Video Export Templates (FL Studio Mobile / InShot style)

    enum VideoTemplate: String, CaseIterable, Identifiable {
        case youtube1080 = "YouTube 1080p"
        case youtube4k = "YouTube 4K"
        case instagramFeed = "Instagram Feed"
        case instagramReels = "Instagram Reels"
        case tiktok = "TikTok"
        case custom1080 = "HD 1080p"
        case custom4k = "4K Master"
        case proRes = "ProRes 422"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .youtube1080, .youtube4k: return "play.rectangle.fill"
            case .instagramFeed, .instagramReels: return "camera.fill"
            case .tiktok: return "music.note"
            case .custom1080: return "film"
            case .custom4k: return "sparkles.tv"
            case .proRes: return "film.stack"
            }
        }

        var accentColor: Color {
            switch self {
            case .youtube1080, .youtube4k: return EchoelBrand.coral
            case .instagramFeed, .instagramReels: return EchoelBrand.violet
            case .tiktok: return EchoelBrand.sky
            case .custom1080, .custom4k: return EchoelBrand.primary
            case .proRes: return EchoelBrand.amber
            }
        }

        var aspectLabel: String {
            switch self {
            case .youtube1080, .youtube4k, .custom1080, .custom4k, .proRes: return "16:9"
            case .instagramFeed: return "1:1"
            case .instagramReels, .tiktok: return "9:16"
            }
        }

        var resolutionLabel: String {
            switch self {
            case .youtube1080: return "1920×1080"
            case .youtube4k: return "3840×2160"
            case .instagramFeed: return "1080×1080"
            case .instagramReels: return "1080×1920"
            case .tiktok: return "1080×1920"
            case .custom1080: return "1920×1080"
            case .custom4k: return "3840×2160"
            case .proRes: return "1920×1080"
            }
        }

        var description: String {
            switch self {
            case .youtube1080: return "H.264 High, 10 Mbps, -13 LUFS"
            case .youtube4k: return "H.265, 35 Mbps, -13 LUFS"
            case .instagramFeed: return "H.264, 5 Mbps, square format"
            case .instagramReels: return "H.264, 8 Mbps, vertical 9:16"
            case .tiktok: return "H.264, 8 Mbps, vertical 9:16"
            case .custom1080: return "H.264 High, universal format"
            case .custom4k: return "H.265, maximum quality"
            case .proRes: return "ProRes 422, post-production"
            }
        }

        var format: VideoExportManager.ExportFormat {
            switch self {
            case .youtube1080, .instagramFeed, .instagramReels, .tiktok, .custom1080:
                return .h264_high
            case .youtube4k, .custom4k:
                return .hevc_main
            case .proRes:
                return .prores422
            }
        }

        var resolution: VideoExportManager.Resolution {
            switch self {
            case .youtube4k, .custom4k: return .uhd3840x2160
            default: return .hd1920x1080
            }
        }

        var quality: VideoExportManager.Quality {
            switch self {
            case .youtube4k, .custom4k, .proRes: return .maximum
            case .youtube1080, .custom1080: return .high
            default: return .high
            }
        }

        var isRecommended: Bool {
            self == .youtube1080
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: EchoelSpacing.lg) {
                    templateGrid
                    selectedTemplateDetail
                    exportProgressSection
                    errorSection
                    successSection

                    Spacer(minLength: EchoelSpacing.lg)

                    exportButton
                }
                .padding(EchoelSpacing.lg)
            }
            .background(EchoelBrand.bgDeep.ignoresSafeArea())
            .navigationTitle("Export Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EchoelBrand.primary)
                }
            }
        }
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundColor(EchoelBrand.textSecondary)
                Text("TEMPLATES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(1.5)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: EchoelSpacing.sm)],
                spacing: EchoelSpacing.sm
            ) {
                ForEach(VideoTemplate.allCases) { template in
                    templateCard(template)
                }
            }
        }
    }

    private func templateCard(_ template: VideoTemplate) -> some View {
        let isSelected = selectedTemplate == template

        return Button {
            withAnimation(.easeInOut(duration: EchoelAnimation.quick)) {
                selectedTemplate = template
            }
            HapticHelper.impact(.light)
        } label: {
            VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? template.accentColor : EchoelBrand.textSecondary)

                    Spacer()

                    Text(template.aspectLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? template.accentColor : EchoelBrand.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                        ? template.accentColor.opacity(0.15)
                                        : EchoelBrand.border.opacity(0.3)
                                )
                        )

                    if template.isRecommended {
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

                Text(template.rawValue)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(isSelected ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)
                    .lineLimit(1)

                Text(template.resolutionLabel)
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundColor(EchoelBrand.textTertiary)
            }
            .padding(EchoelSpacing.sm + EchoelSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(isSelected ? template.accentColor.opacity(0.06) : EchoelBrand.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .stroke(
                        isSelected ? template.accentColor.opacity(0.4) : EchoelBrand.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Template Detail

    private var selectedTemplateDetail: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(EchoelBrand.textSecondary)
                Text("SETTINGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(1.5)
            }

            VStack(spacing: EchoelSpacing.sm) {
                detailRow(label: "Format", value: selectedTemplate.format.rawValue)
                detailRow(label: "Resolution", value: selectedTemplate.resolutionLabel)
                detailRow(label: "Aspect Ratio", value: selectedTemplate.aspectLabel)
                detailRow(label: "Quality", value: selectedTemplate.quality.rawValue)
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
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textTertiary)
            Spacer()
            Text(value)
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.textPrimary)
        }
    }

    // MARK: - Progress / Error / Success

    @ViewBuilder
    private var exportProgressSection: some View {
        if exportManager.isExporting {
            VStack(spacing: EchoelSpacing.sm) {
                ProgressView(value: exportManager.exportProgress)
                    .tint(selectedTemplate.accentColor)
                Text("\(Int(exportManager.exportProgress * 100))% — Rendering \(selectedTemplate.rawValue)...")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .padding(EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                    .fill(EchoelBrand.bgSurface)
            )
        }
    }

    @ViewBuilder
    private var errorSection: some View {
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
    }

    @ViewBuilder
    private var successSection: some View {
        if exportSuccess {
            HStack(spacing: EchoelSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(EchoelBrand.emerald)
                Text("Video exported successfully")
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
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            Task { await performExport() }
        } label: {
            HStack(spacing: EchoelSpacing.sm) {
                if exportManager.isExporting {
                    ProgressView()
                        .tint(EchoelBrand.bgDeep)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(exportManager.isExporting ? "Exporting..." : "Export \(selectedTemplate.rawValue)")
                    .fontWeight(.semibold)
            }
            .font(EchoelBrandFont.body())
            .foregroundColor(EchoelBrand.bgDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.md)
            .background(
                Capsule()
                    .fill(exportManager.isExporting ? EchoelBrand.textTertiary : selectedTemplate.accentColor)
            )
        }
        .disabled(exportManager.isExporting)
        .buttonStyle(.plain)
    }

    // MARK: - Export Logic

    private func performExport() async {
        exportError = nil
        exportSuccess = false

        guard let composition = try? await engine.buildComposition() else {
            exportError = "No video content to export"
            return
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let outputURL = documentsDir
            .appendingPathComponent("Echoelmusic_\(selectedTemplate.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension(selectedTemplate.format.fileExtension)

        do {
            try await exportManager.export(
                composition: composition,
                to: outputURL,
                format: selectedTemplate.format,
                resolution: selectedTemplate.resolution,
                quality: selectedTemplate.quality
            )
            exportSuccess = true
            HapticHelper.notification(.success)

            // Share the exported file
            #if os(iOS)
            let activityVC = UIActivityViewController(activityItems: [outputURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                rootVC.present(activityVC, animated: true)
            }
            #endif
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
            HapticHelper.notification(.error)
        }
    }
}

// MARK: - Video Picker Sheet (iOS 16+)

@available(iOS 16.0, *)
struct VideoPickerSheet: View {
    @Bindable var engine: VideoEditingEngine
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
            .onChange(of: selectedItems) { _, _ in
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
        // swiftlint:disable:next force_cast — guaranteed by layerClass override
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
#endif
