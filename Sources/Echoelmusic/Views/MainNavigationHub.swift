#if canImport(SwiftUI)
import SwiftUI

/// Main navigation — Echoelmusic unified workspace
struct MainNavigationHub: View {

    @Environment(AudioEngine.self) var audioEngine
    @Environment(MicrophoneManager.self) var microphoneManager
    @Environment(RecordingEngine.self) var recordingEngine
    @Environment(ThemeManager.self) var themeManager

    @State private var showSettings = false
    @State private var showStudio = false
    @State private var recordingError: String?

    var body: some View {
        VStack(spacing: 0) {
            if showStudio {
                // Full studio mode
                VStack(spacing: 0) {
                    topBar

                    EchoelStudioView()
                        .environment(audioEngine)
                        .environment(recordingEngine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    transportBar
                }
            } else {
                // Bio Music — the main experience
                BioMusicView()
            }
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            // Toggle between Bio Music and Studio
            Button {
                showStudio.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showStudio ? "heart.fill" : "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                    Text(showStudio ? "Bio Music" : "Studio")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, EchoelSpacing.sm)
                .padding(.vertical, EchoelSpacing.xs)
                .background(EchoelBrand.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.sm)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
                .foregroundStyle(EchoelBrand.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, EchoelSpacing.md)
            .padding(.top, EchoelSpacing.xs)
        }
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

    // MARK: - Top Bar (Clean — no branding, functional only)

    private var topBar: some View {
        HStack(spacing: EchoelSpacing.sm) {
            // CPU / Performance indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(audioEngine.isRunning ? EchoelBrand.emerald : EchoelBrand.textTertiary)
                    .frame(width: 6, height: 6)
                Text(audioEngine.isRunning ? "Audio" : "Off")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(audioEngine.isRunning ? EchoelBrand.emerald : EchoelBrand.textTertiary)
            }

            Spacer()

            // Settings gear — top-right
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, EchoelSpacing.md)
        .frame(height: 36)
        .background(
            EchoelBrand.bgSurface.opacity(0.92)
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Transport Bar (Ableton-Style)

    @State private var tapTempoTimes: [Date] = []
    @State private var isLoopEnabled = false

    private var transportBar: some View {
        HStack(spacing: 0) {
            // Position Display (Bars.Beats.Ticks — Ableton style)
            positionDisplay

            transportDivider

            // BPM + Tap Tempo + Time Signature
            bpmSection

            transportDivider

            // Transport Controls (centered)
            transportControls

            Spacer()

            // Loop Toggle
            Button {
                isLoopEnabled.toggle()
                HapticHelper.impact(.light)
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isLoopEnabled ? EchoelBrand.amber : EchoelBrand.textTertiary)
                    .frame(minWidth: 32, minHeight: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isLoopEnabled ? EchoelBrand.amber.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLoopEnabled ? "Disable loop" : "Enable loop")

            transportDivider

            // Time display (MM:SS:ms)
            Text(formatTime(recordingEngine.currentTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 60)

            transportDivider

            // Bio-feedback indicator
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

    /// Bars.Beats.Ticks position display (Ableton Live style)
    private var positionDisplay: some View {
        let bpm = max(EchoelCreativeWorkspace.shared.globalBPM, 20.0)
        let time = recordingEngine.currentTime
        let beatsPerSecond = bpm / 60.0
        let totalBeats = time * beatsPerSecond
        let bars = Int(totalBeats / 4) + 1
        let beats = Int(totalBeats.truncatingRemainder(dividingBy: 4)) + 1
        let ticks = Int((totalBeats.truncatingRemainder(dividingBy: 1)) * 100)

        return HStack(spacing: 1) {
            Text(String(format: "%3d", bars))
                .foregroundColor(EchoelBrand.textPrimary)
            Text(".")
                .foregroundColor(EchoelBrand.textTertiary)
            Text(String(format: "%d", beats))
                .foregroundColor(EchoelBrand.primary)
            Text(".")
                .foregroundColor(EchoelBrand.textTertiary)
            Text(String(format: "%02d", ticks))
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .frame(minWidth: 70)
    }

    /// BPM display with tap tempo (Ableton style)
    private var bpmSection: some View {
        HStack(spacing: EchoelSpacing.xs) {
            // Time Signature
            Text("4/4")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(EchoelBrand.bgElevated)
                )

            // BPM value
            Text(String(format: "%.1f", EchoelCreativeWorkspace.shared.globalBPM))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 44)

            // Tap tempo button
            Button {
                handleTapTempo()
                HapticHelper.impact(.light)
            } label: {
                Text("TAP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(EchoelBrand.coral)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(EchoelBrand.coral.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tap tempo")
        }
    }

    /// Transport control buttons (Ableton-style layout)
    private var transportControls: some View {
        HStack(spacing: EchoelSpacing.xs) {
            // Return to start
            Button(action: {
                recordingEngine.seek(to: 0)
                HapticHelper.impact(.light)
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to start")

            // Play/Pause
            Button(action: {
                EchoelCreativeWorkspace.shared.togglePlayback()
                HapticHelper.impact(.medium)
            }) {
                ZStack {
                    let isPlaying = EchoelCreativeWorkspace.shared.isPlaying

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPlaying ? EchoelBrand.emerald.opacity(0.15) : EchoelBrand.bgElevated)
                        .frame(width: 32, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isPlaying ? EchoelBrand.emerald.opacity(0.4) : EchoelBrand.border, lineWidth: 1)
                        )

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isPlaying ? EchoelBrand.emerald : EchoelBrand.textPrimary)
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(EchoelCreativeWorkspace.shared.isPlaying ? "Pause" : "Play")

            // Stop
            Button(action: {
                if EchoelCreativeWorkspace.shared.isPlaying {
                    EchoelCreativeWorkspace.shared.togglePlayback()
                }
                audioEngine.stop()
                HapticHelper.impact(.light)
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop")

            // Record
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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(recordingEngine.isRecording ? EchoelBrand.coral.opacity(0.2) : Color.clear)
                        .frame(width: 32, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(recordingEngine.isRecording ? EchoelBrand.coral.opacity(0.5) : EchoelBrand.border, lineWidth: 1)
                        )

                    Circle()
                        .fill(recordingEngine.isRecording ? EchoelBrand.coral : EchoelBrand.coral.opacity(0.5))
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recordingEngine.isRecording ? "Stop recording" : "Record")
        }
    }

    /// Tap tempo calculation
    private func handleTapTempo() {
        let now = Date()
        tapTempoTimes.append(now)

        // Keep only last 6 taps within 3 seconds
        tapTempoTimes = tapTempoTimes.filter { now.timeIntervalSince($0) < 3.0 }

        guard tapTempoTimes.count >= 2 else { return }

        var intervals: [TimeInterval] = []
        for i in 1..<tapTempoTimes.count {
            intervals.append(tapTempoTimes[i].timeIntervalSince(tapTempoTimes[i - 1]))
        }

        guard !intervals.isEmpty else { return }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard avgInterval > 0 else { return }

        let newBPM = 60.0 / avgInterval
        let clampedBPM = max(20.0, min(300.0, newBPM))
        EchoelCreativeWorkspace.shared.globalBPM = clampedBPM
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bio feedback, \(audioEngine.isRunning ? "active" : "inactive")")
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
                                settingsRow(icon: "info.circle", label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "7.0")
                                settingsRow(icon: "hammer", label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev")
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
                                // Stop fallback streaming, restart with HealthKit
                                bio.stopStreaming()
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
    @Bindable private var bio = EchoelBioEngine.shared

    var body: some View {
        HStack(spacing: EchoelSpacing.xs) {
            let level = CGFloat(workspace.bioCoherence)
            let hasRealData = bio.isStreaming && bio.dataSource != .fallback
            let coherenceColor: Color = hasRealData
                ? (level > 0.6 ? EchoelBrand.coherenceHigh
                    : level > 0.3 ? EchoelBrand.coherenceMedium
                    : EchoelBrand.coherenceLow)
                : EchoelBrand.textDisabled

            ZStack {
                // Coherence arc (progress ring)
                Circle()
                    .stroke(coherenceColor.opacity(0.15), lineWidth: 2)
                    .frame(width: 16, height: 16)

                Circle()
                    .trim(from: 0, to: hasRealData ? max(0.05, level) : 0)
                    .stroke(coherenceColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(-90))

                // Heart pulse dot
                Circle()
                    .fill(coherenceColor)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 0) {
                Text("BIO")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textSecondary)
                Text(bioSourceLabel)
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(bioSourceColor)
            }
        }
    }

    private var bioSourceLabel: String {
        guard isAudioRunning else { return "OFF" }
        switch bio.dataSource {
        case .healthKit, .appleWatch, .chestStrap: return "HK"
        case .camera: return "CAM"
        case .ouraRing: return "OURA"
        case .arkit: return "AR"
        case .microphone: return "MIC"
        case .fallback: return "SIM"
        }
    }

    private var bioSourceColor: Color {
        guard isAudioRunning else { return EchoelBrand.textDisabled }
        switch bio.dataSource {
        case .healthKit, .appleWatch, .chestStrap: return EchoelBrand.emerald
        case .camera: return EchoelBrand.sky
        case .ouraRing: return EchoelBrand.violet
        case .arkit: return EchoelBrand.sky
        case .microphone: return EchoelBrand.amber
        case .fallback: return EchoelBrand.textSecondary
        }
    }
}
#endif
