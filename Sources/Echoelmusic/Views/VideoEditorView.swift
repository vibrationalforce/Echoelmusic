import SwiftUI

// MARK: - Video Editor View
// Homogeneous GUI with VaporwaveTheme - "Flüssiges Licht"

/// Professional video editing interface with bio-reactive features
struct VideoEditorView: View {
    @StateObject private var engine = VideoEditingEngine()
    @EnvironmentObject var healthKitManager: HealthKitManager
    @ObservedObject private var bridge = WorkspaceIntegrationBridge.shared

    @State private var selectedClipIndex: Int?
    @State private var timelineZoom: Double = 1.0
    @State private var showEffectsPanel = false
    @State private var showExportSheet = false
    @State private var appliedEffects: [String] = []

    /// Video playhead synced from engine
    private var currentTime: TimeInterval { engine.playheadSeconds }
    private var isPlaying: Bool { engine.isPlaying }

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

                Text("Bio-Reactive Editing")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }

            Spacer()

            // Toolbar buttons
            HStack(spacing: VaporwaveSpacing.sm) {
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

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Video Preview Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(VaporwaveColors.deepBlack)

                // Preview content - check if timeline has any clips
                if !engine.timeline.videoTracks.flatMap({ $0.clips }).isEmpty ||
                   !engine.timeline.audioTracks.flatMap({ $0.clips }).isEmpty {
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
                metricDisplay(value: formatDuration(engine.timeline.duration.seconds), label: "Duration", color: VaporwaveColors.neonPink)
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
                let isApplied = appliedEffects.contains(effect)
                Button {
                    applyEffect(effect, category: title)
                } label: {
                    HStack {
                        Text(effect)
                            .font(VaporwaveTypography.body())
                            .foregroundColor(isApplied ? VaporwaveColors.neonCyan : VaporwaveColors.textPrimary)
                        Spacer()
                        Image(systemName: isApplied ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(isApplied ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
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

    /// Apply an effect to the selected clip or globally
    private func applyEffect(_ effect: String, category: String) {
        // Toggle effect
        if appliedEffects.contains(effect) {
            appliedEffects.removeAll { $0 == effect }
            engine.removeEffect(named: effect)
        } else {
            appliedEffects.append(effect)

            // Map UI effect names to engine effect types
            let videoEffect = mapEffectToEngine(effect, category: category)
            if let clipIndex = selectedClipIndex {
                engine.applyEffect(videoEffect, toClipAt: clipIndex)
            } else {
                engine.applyGlobalEffect(videoEffect)
            }
        }

        #if DEBUG
        print("[VideoEditor] Effect '\(effect)' \(appliedEffects.contains(effect) ? "applied" : "removed")")
        #endif
    }

    /// Map UI effect name to VideoEffect using VideoEffectCategory
    private func mapEffectToEngine(_ effect: String, category: String) -> VideoEffect {
        switch effect {
        // Color effects
        case "Auto Color": return VideoEffect(type: VideoEffectCategory.autoColor, intensity: 1.0)
        case "LUT": return VideoEffect(type: VideoEffectCategory.lut, intensity: 1.0)
        case "Color Grade": return VideoEffect(type: VideoEffectCategory.colorGrade, intensity: 1.0)
        case "HDR": return VideoEffect(type: VideoEffectCategory.hdr, intensity: 1.0)

        // Style effects
        case "Cinematic": return VideoEffect(type: VideoEffectCategory.cinematic, intensity: 1.0)
        case "Vintage": return VideoEffect(type: VideoEffectCategory.vintage, intensity: 0.8)
        case "Neon Glow": return VideoEffect(type: VideoEffectCategory.neonGlow, intensity: 1.0)
        case "Glitch": return VideoEffect(type: VideoEffectCategory.glitch, intensity: 0.5)

        // Bio-reactive effects
        case "Coherence Pulse":
            return VideoEffect(type: VideoEffectCategory.bioCoherence, intensity: Float(bridge.hrvCoherence))
        case "Heart Sync":
            return VideoEffect(type: VideoEffectCategory.bioHeartbeat, intensity: Float(bridge.heartRate / 200))
        case "Breath Flow":
            return VideoEffect(type: VideoEffectCategory.bioBreathing, intensity: Float(bridge.breathingRate / 30))

        // AI effects
        case "Style Transfer": return VideoEffect(type: VideoEffectCategory.aiStyleTransfer, intensity: 1.0)
        case "Face Enhance": return VideoEffect(type: VideoEffectCategory.aiFaceEnhance, intensity: 1.0)
        case "Background Remove": return VideoEffect(type: VideoEffectCategory.aiBackgroundRemove, intensity: 1.0)

        default: return VideoEffect(type: VideoEffectCategory.none, intensity: 0)
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Timeline header
            HStack {
                Text("TIMELINE")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .tracking(2)

                Spacer()

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

            // Timeline tracks
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: VaporwaveSpacing.xs) {
                    // Video track
                    timelineTrack(name: "Video", color: VaporwaveColors.neonCyan, clips: engine.videoClips)

                    // Audio track
                    timelineTrack(name: "Audio", color: VaporwaveColors.neonPurple, clips: engine.audioClips)

                    // Bio track
                    timelineTrack(name: "Bio-Sync", color: VaporwaveColors.neonPink, clips: [])
                }
                .padding(.horizontal, VaporwaveSpacing.md)
            }
            .frame(height: 150)
            .modifier(GlassCard())
            .padding(.horizontal, VaporwaveSpacing.md)
        }
    }

    private func timelineTrack(name: String, color: Color, clips: [VideoClip]) -> some View {
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

    private func clipView(clip: VideoClip, color: Color, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(isSelected ? 0.6 : 0.3))
            .frame(width: CGFloat(clip.duration.seconds * 10 * timelineZoom), height: 36)
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
            // Timecode display
            VStack(spacing: 2) {
                Text(formatTimecode(currentTime))
                    .font(VaporwaveTypography.data())
                    .foregroundColor(VaporwaveColors.neonCyan)
                Text("TIMECODE")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .frame(width: 100)

            Spacer()

            // Skip back - WIRED TO ENGINE
            transportButton(icon: "backward.fill") {
                engine.seek(to: max(0, currentTime - 5))
            }

            // Previous frame - WIRED TO ENGINE
            transportButton(icon: "backward.frame.fill") {
                engine.seek(to: max(0, currentTime - 1/30))
            }

            // Play/Pause - WIRED TO ENGINE
            Button {
                if isPlaying {
                    engine.pause()
                } else {
                    engine.play()
                }
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

            // Next frame - WIRED TO ENGINE
            transportButton(icon: "forward.frame.fill") {
                engine.seek(to: currentTime + 1/30)
            }

            // Skip forward - WIRED TO ENGINE
            transportButton(icon: "forward.fill") {
                engine.seek(to: currentTime + 5)
            }

            Spacer()

            // Bio-sync indicator for video
            HStack(spacing: VaporwaveSpacing.sm) {
                Circle()
                    .fill(bridge.bioSyncEnabled ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
                    .frame(width: 8, height: 8)

                Text("\(Int(bridge.hrvCoherence * 100))%")
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.neonPink)
            }
            .frame(width: 60)
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }

    /// Format timecode as HH:MM:SS:FF
    private func formatTimecode(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let frames = Int((time - floor(time)) * 30)
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
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

#Preview {
    VideoEditorView()
}
