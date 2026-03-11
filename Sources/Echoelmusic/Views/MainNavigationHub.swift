#if canImport(SwiftUI)
import SwiftUI

/// Main navigation — Echoelmusic unified workspace
struct MainNavigationHub: View {

    @Environment(AudioEngine.self) var audioEngine
    @Environment(MicrophoneManager.self) var microphoneManager
    @Environment(RecordingEngine.self) var recordingEngine
    @Environment(ThemeManager.self) var themeManager

    @State private var showSettings = false
    @State private var recordingError: String?

    var body: some View {
        VStack(spacing: 0) {
            topBar

            // Unified studio workspace
            EchoelStudioView()
                .environment(audioEngine)
                .environment(recordingEngine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Transport bar (shared)
            transportBar
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            EchoelSettingsView()
                .environment(themeManager)
                .environment(audioEngine)
        }
        .alert("Recording Error", isPresented: Binding(
            get: { recordingError != nil },
            set: { if !$0 { recordingError = nil } }
        )) {
            Button("OK") { recordingError = nil }
        } message: {
            Text(recordingError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Top Bar (iPad)

    private var topBar: some View {
        HStack(spacing: EchoelSpacing.sm) {
            Text("ECHOELMUSIC")
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textPrimary.opacity(0.7))
                .tracking(4)
                .kerning(0.5)

            Spacer()

            // Settings gear
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.xs)
                            .fill(EchoelBrand.bgElevated.opacity(0.5))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm)
        .background(
            ZStack {
                EchoelBrand.bgSurface.opacity(0.92)
                if #available(iOS 15.0, *) {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.25)
                }
            }
            .overlay(
                Rectangle()
                    .fill(EchoelBrand.border)
                    .frame(height: 0.5),
                alignment: .bottom
            )
        )
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: 0) {
            // BPM Section
            HStack(spacing: EchoelSpacing.xxs) {
                Text("\(Int(EchoelCreativeWorkspace.shared.globalBPM))")
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .monospacedDigit()
                Text("BPM")
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .padding(.top, 1)
            }

            transportDivider

            // Transport Controls
            HStack(spacing: EchoelSpacing.sm + EchoelSpacing.xxs) {
                Button(action: {
                    let newTime = max(0, recordingEngine.currentTime - 5.0)
                    recordingEngine.seek(to: newTime)
                    HapticHelper.impact(.light)
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    // Toggle workspace playback — syncs ALL engines (audio, video, session, loops)
                    EchoelCreativeWorkspace.shared.togglePlayback()
                    HapticHelper.impact(.medium)
                }) {
                    ZStack {
                        let isPlaying = EchoelCreativeWorkspace.shared.isPlaying
                        // Outer glow ring when playing
                        Circle()
                            .fill(isPlaying ? EchoelBrand.primary.opacity(0.08) : Color.clear)
                            .frame(width: 42, height: 42)

                        Circle()
                            .fill(isPlaying ? EchoelBrand.primary.opacity(0.15) : EchoelBrand.bgElevated)
                            .frame(width: 36, height: 36)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isPlaying ? EchoelBrand.primary : EchoelBrand.textPrimary)
                            .offset(x: isPlaying ? 0 : 1) // Optical center for play triangle
                    }
                    .shadow(
                        color: EchoelCreativeWorkspace.shared.isPlaying ? EchoelBrand.primary.opacity(0.35) : Color.clear,
                        radius: EchoelCreativeWorkspace.shared.isPlaying ? 10 : 0
                    )
                    .shadow(
                        color: EchoelCreativeWorkspace.shared.isPlaying ? EchoelBrand.primary.opacity(0.15) : Color.clear,
                        radius: EchoelCreativeWorkspace.shared.isPlaying ? 20 : 0
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    if EchoelCreativeWorkspace.shared.isPlaying {
                        EchoelCreativeWorkspace.shared.togglePlayback()
                    }
                    audioEngine.stop()
                    HapticHelper.impact(.light)
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(EchoelBrand.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    do {
                        if recordingEngine.isRecording {
                            try recordingEngine.stopRecording()
                            HapticHelper.notification(.success)
                        } else {
                            try recordingEngine.startRecording()
                            HapticHelper.impact(.heavy)
                        }
                    } catch {
                        recordingError = error.localizedDescription
                        HapticHelper.notification(.error)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(recordingEngine.isRecording ? EchoelBrand.coral : EchoelBrand.coral.opacity(0.4))
                            .frame(width: 12, height: 12)

                        if recordingEngine.isRecording {
                            Circle()
                                .stroke(EchoelBrand.coral.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Time display
            Text(formatTime(recordingEngine.currentTime))
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.textSecondary)
                .monospacedDigit()

            transportDivider

            // Bio-feedback indicator (mic level as proxy when no HealthKit)
            bioFeedbackIndicator

            transportDivider

            // Stereo LED meters
            HStack(spacing: EchoelSpacing.xs) {
                segmentedMeter(level: audioEngine.masterLevel, label: "L")
                segmentedMeter(level: audioEngine.masterLevelR, label: "R")
            }
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.sm - EchoelSpacing.xxs)
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

    /// Visual divider between transport bar sections
    private var transportDivider: some View {
        Rectangle()
            .fill(EchoelBrand.border)
            .frame(width: 1, height: 20)
            .padding(.horizontal, EchoelSpacing.sm)
    }

    /// Segmented LED-style level meter (DAW transport style)
    private func segmentedMeter(level: Float, label: String) -> some View {
        HStack(spacing: EchoelSpacing.xxs) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .frame(width: 8)

            HStack(spacing: 1) {
                ForEach(0..<16, id: \.self) { segment in
                    let threshold = Float(segment) / 16.0
                    let isLit = level > threshold
                    let segmentColor: Color = {
                        if segment >= 13 { return EchoelBrand.coral }
                        if segment >= 10 { return EchoelBrand.amber }
                        return EchoelBrand.emerald
                    }()

                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(isLit ? segmentColor : segmentColor.opacity(0.08))
                        .frame(width: 2.5, height: 8)
                        .animation(.linear(duration: isLit ? 0.02 : 0.15), value: isLit)
                }
            }
        }
    }

    /// Bio-feedback indicator — delegates to isolated subview to avoid re-rendering transport bar
    private var bioFeedbackIndicator: some View {
        BioFeedbackIndicatorView(isAudioRunning: audioEngine.isRunning)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, millis)
    }
}

// MARK: - Settings View

struct EchoelSettingsView: View {
    @Environment(ThemeManager.self) var themeManager
    @Environment(AudioEngine.self) var audioEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                EchoelBrand.bgDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EchoelSpacing.lg) {

                        // MARK: - Appearance
                        settingsSection(title: "APPEARANCE") {
                            ThemeModePicker(themeManager: themeManager)
                                .padding(.horizontal, EchoelSpacing.md)
                        }

                        // MARK: - Audio
                        settingsSection(title: "AUDIO") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "speaker.wave.2",
                                    label: "Master Volume",
                                    value: "\(Int(audioEngine.masterVolume * 100))%"
                                )

                                Slider(
                                    value: Binding(
                                        get: { Double(audioEngine.masterVolume) },
                                        set: { audioEngine.masterVolume = Float($0) }
                                    ),
                                    in: 0...1
                                )
                                .tint(EchoelBrand.primary)
                                .padding(.horizontal, EchoelSpacing.md)

                                settingsRow(
                                    icon: "waveform",
                                    label: "Audio Engine",
                                    value: audioEngine.isRunning ? "Running" : "Stopped"
                                )

                                settingsRow(
                                    icon: "mic",
                                    label: "Input Monitoring",
                                    value: audioEngine.inputMonitoringEnabled ? "On" : "Off"
                                )
                            }
                        }

                        // MARK: - Sync
                        settingsSection(title: "SYNC") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "link",
                                    label: "Ableton Link",
                                    value: EchoelCreativeWorkspace.shared.linkClient.isEnabled ? "Active" : "Off"
                                )
                                settingsRow(
                                    icon: "antenna.radiowaves.left.and.right",
                                    label: "Link Peers",
                                    value: "\(EchoelCreativeWorkspace.shared.linkClient.peers.count)"
                                )
                            }
                        }

                        // MARK: - Bio-Feedback
                        settingsSection(title: "BIO-FEEDBACK") {
                            BioFeedbackSettingsContent()
                        }

                        // MARK: - Safety
                        settingsSection(title: "SAFETY") {
                            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                                safetyWarning("NOT while operating vehicles")
                                safetyWarning("NOT under influence of alcohol/drugs")
                                safetyWarning("Max 3 Hz visual flash rate (WCAG)")
                                safetyWarning("Coordinate therapeutic use with your provider")
                            }
                            .padding(.horizontal, EchoelSpacing.md)
                        }

                        // MARK: - Tuning
                        settingsSection(title: "TUNING") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(
                                    icon: "tuningfork",
                                    label: "Concert Pitch (A4)",
                                    value: String(format: "%.1f Hz", TuningManager.shared.concertPitch)
                                )
                                KammertonWheelView()
                                    .padding(.horizontal, EchoelSpacing.sm)
                            }
                        }

                        // MARK: - About
                        settingsSection(title: "ABOUT") {
                            VStack(spacing: EchoelSpacing.sm) {
                                settingsRow(icon: "info.circle", label: "Version", value: "7.0")
                                settingsRow(icon: "hammer", label: "Build", value: "22572541274")
                                settingsRow(icon: "person", label: "Developer", value: "Echoel")
                                settingsRow(icon: "building.2", label: "Studio", value: "Hamburg")

                                Text("Create from Within")
                                    .font(EchoelBrandFont.caption())
                                    .foregroundColor(EchoelBrand.textSecondary)
                                    .italic()
                                    .padding(.top, EchoelSpacing.xs)
                            }
                        }
                    }
                    .padding(.vertical, EchoelSpacing.lg)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EchoelBrand.primary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(2)
                .padding(.horizontal, EchoelSpacing.lg)

            VStack(spacing: EchoelSpacing.xs) {
                content()
            }
            .padding(.vertical, EchoelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EchoelRadius.md)
                    .fill(EchoelBrand.bgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.md)
                            .stroke(EchoelBrand.border, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, EchoelSpacing.md)
        }
    }

    private func settingsRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(EchoelBrand.primary)
                .frame(width: 24)

            Text(label)
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.textPrimary)

            Spacer()

            Text(value)
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, EchoelSpacing.md)
    }

    private func safetyWarning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: EchoelSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(EchoelBrand.amber)
                .padding(.top, 2)

            Text(text)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)
        }
    }
}

// MARK: - Bio-Feedback Settings Content

/// HealthKit authorization and bio streaming controls for the settings sheet.
/// Extracted to isolate @Bindable observation from the rest of EchoelSettingsView.
private struct BioFeedbackSettingsContent: View {
    @Bindable private var bio = EchoelBioEngine.shared
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: EchoelSpacing.sm) {
            // Authorization status
            HStack {
                Image(systemName: bio.isAuthorized ? "heart.fill" : "heart.slash")
                    .font(.system(size: 14))
                    .foregroundColor(bio.isAuthorized ? EchoelBrand.primary : EchoelBrand.textSecondary)
                    .frame(width: 24)

                Text("HealthKit")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)

                Spacer()

                if bio.isAuthorized {
                    Text("Authorized")
                        .font(EchoelBrandFont.dataSmall())
                        .foregroundColor(EchoelBrand.emerald)
                } else {
                    Button(action: {
                        isRequesting = true
                        Task { @MainActor in
                            let granted = await bio.requestAuthorization()
                            isRequesting = false
                            if granted {
                                bio.startStreaming()
                            }
                        }
                    }) {
                        if isRequesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Authorize")
                                .font(EchoelBrandFont.dataSmall())
                                .foregroundColor(EchoelBrand.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequesting)
                }
            }
            .padding(.horizontal, EchoelSpacing.md)

            // Streaming status
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14))
                    .foregroundColor(bio.isStreaming ? EchoelBrand.emerald : EchoelBrand.textSecondary)
                    .frame(width: 24)

                Text("Bio Streaming")
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)

                Spacer()

                Text(bio.isStreaming ? bio.snapshot.source.rawValue : "Off")
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundColor(bio.isStreaming ? EchoelBrand.emerald : EchoelBrand.textSecondary)
            }
            .padding(.horizontal, EchoelSpacing.md)

            // Disclaimer
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundColor(EchoelBrand.amber)
                Text("Bio data is for self-observation, not medical diagnosis.")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .padding(.horizontal, EchoelSpacing.md)
        }
        .task {
            // Auto-request on appear if not yet authorized
            if !bio.isAuthorized && !bio.isStreaming {
                let granted = await bio.requestAuthorization()
                if granted {
                    bio.startStreaming()
                }
            }
        }
    }
}

// MARK: - Isolated Bio Feedback Indicator

/// Isolated view that only re-renders when bioCoherence or audio running state changes.
/// Prevents 60Hz+ coherence updates from triggering full transport bar re-render.
private struct BioFeedbackIndicatorView: View {
    let isAudioRunning: Bool
    private let workspace = EchoelCreativeWorkspace.shared

    var body: some View {
        HStack(spacing: EchoelSpacing.xs) {
            let level = CGFloat(workspace.bioCoherence)
            let coherenceColor: Color = level > 0.6 ? EchoelBrand.coherenceHigh
                : level > 0.3 ? EchoelBrand.coherenceMedium
                : EchoelBrand.coherenceLow

            ZStack {
                Circle()
                    .stroke(coherenceColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 18, height: 18)

                Circle()
                    .trim(from: 0, to: max(0.05, level))
                    .stroke(coherenceColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(coherenceColor)
                    .frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("BIO")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textSecondary)
                Text(isAudioRunning ? "LIVE" : "OFF")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(isAudioRunning ? EchoelBrand.emerald : EchoelBrand.textDisabled)
            }
        }
    }
}
#endif
