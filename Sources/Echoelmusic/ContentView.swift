import SwiftUI

/// Main user interface for the Echoelmusic app
/// Optimized with proper state management, error handling, and unified design system
struct ContentView: View {

    // MARK: - Environment

    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var healthKitEngine: UnifiedHealthKitEngine
    @EnvironmentObject var recordingEngine: RecordingEngine

    // MARK: - State

    @State private var showPermissionAlert = false
    @State private var showRecordingControls = false
    @State private var showBinauralControls = false
    @State private var showSpatialControls = false
    @State private var showVisualizationPicker = false
    @State private var selectedVisualizationMode: VisualizationMode = .particles
    @State private var selectedBrainwaveState: BinauralBeatGenerator.BrainwaveState = .alpha
    @State private var binauralAmplitude: Float = 0.3
    @State private var pulseAnimation = false
    @StateObject private var cymaticsVisualizer = CymaticsVisualizer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Computed property - single source of truth for recording state
    private var isRecording: Bool {
        microphoneManager.isRecording
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background - using design system
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.xl) {

                // App Title with neon glow
                Text("Echoelmusic")
                    .font(VaporwaveTypography.heroTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .neonGlow(color: isRecording ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan, radius: pulseAnimation ? 20 : 12)
                    .padding(.top, VaporwaveSpacing.xxl)
                    .accessibilityLabel("Echoelmusic - Bio-reactive music application")

                Text("breath → sound")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .tracking(4)
                    .accessibilityLabel("breath to sound")

                Spacer()

                // Visualization (mode-based)
                visualizationView
                    .frame(height: 350)
                    .padding(.horizontal, VaporwaveSpacing.lg)
                    .accessibilityLabel("Audio visualization display")

                // Visualization mode picker button
                Button(action: { showVisualizationPicker.toggle() }) {
                    HStack(spacing: VaporwaveSpacing.xs) {
                        Image(systemName: selectedVisualizationMode.icon)
                            .font(.system(size: 12))
                        Text(selectedVisualizationMode.rawValue)
                            .font(VaporwaveTypography.label())
                    }
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.xs)
                    .background(
                        Capsule()
                            .fill(selectedVisualizationMode.color.opacity(0.2))
                    )
                }
                .accessibilityLabel("Visualization mode: \(selectedVisualizationMode.rawValue)")
                .accessibilityHint("Double tap to change visualization mode")

                Spacer()

                // Frequency and amplitude display
                if isRecording {
                    audioMetricsDisplay
                        .transition(.opacity.combined(with: .scale))
                }

                // HRV Biofeedback Display
                if healthKitEngine.isAuthorized && isRecording {
                    bioMetricsPanel
                        .transition(.opacity.combined(with: .scale))
                }

                // Audio level bars (improved visualization)
                if isRecording {
                    audioLevelBars
                        .transition(.opacity)
                        .animation(reduceMotion ? nil : VaporwaveAnimation.quick, value: microphoneManager.audioLevel)
                }

                // Control Buttons
                controlButtonsRow
                    .padding(.bottom, VaporwaveSpacing.md)

                // Spatial Audio Controls Panel
                if showSpatialControls && audioEngine.spatialAudioEngine != nil {
                    spatialAudioPanel
                        .transition(.opacity.combined(with: .scale))
                }

                // Multidimensional Brainwave Entrainment controls panel
                if showBinauralControls {
                    binauralControlsPanel
                        .transition(.opacity.combined(with: .scale))
                }

                // Status text
                Text(statusText)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .padding(.bottom, VaporwaveSpacing.xxl)
                    .accessibilityLabel("Status: \(statusText)")
            }
        }
        .onAppear {
            pulseAnimation = true
            checkPermissions()
            Task {
                do {
                    try await healthKitEngine.requestAuthorization()
                } catch {
                    log.error("HealthKit authorization failed: \(error)")
                }
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings", action: openSettings)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Echoelmusic needs microphone access to create music from your voice. Please enable it in Settings.")
        }
        .sheet(isPresented: $showVisualizationPicker) {
            VisualizationModePicker(selectedMode: $selectedVisualizationMode)
        }
        .sheet(isPresented: $showRecordingControls) {
            RecordingControlsView()
                .environmentObject(recordingEngine)
                .environmentObject(healthKitEngine)
                .environmentObject(microphoneManager)
                .presentationDetentsIfAvailable()
        }
    }

    // MARK: - Computed Properties

    /// Status text based on current state
    private var statusText: String {
        if !microphoneManager.hasPermission {
            return "Grant Microphone Access"
        } else if isRecording {
            if microphoneManager.frequency > 50 {
                return "Listening... \(Int(microphoneManager.frequency)) Hz"
            } else {
                return "Listening..."
            }
        } else {
            return "Tap to Start"
        }
    }

    /// Visualization view based on selected mode
    @ViewBuilder
    private var visualizationView: some View {
        switch selectedVisualizationMode {
        case .particles:
            ParticleView(
                isActive: isRecording,
                audioLevel: microphoneManager.audioLevel,
                frequency: microphoneManager.frequency > 0 ? microphoneManager.frequency : nil,
                voicePitch: microphoneManager.currentPitch,
                hrvCoherence: healthKitEngine.coherence * 100,
                heartRate: healthKitEngine.heartRate
            )
        case .cymatics:
            CymaticsView(
                visualizer: cymaticsVisualizer,
                coherence: healthKitEngine.coherence * 100
            )
        case .waveform:
            WaveformMode(
                audioBuffer: microphoneManager.audioBuffer ?? [],
                audioLevel: microphoneManager.audioLevel,
                hrvCoherence: healthKitEngine.coherence * 100
            )
        case .spectral:
            SpectralMode(
                fftMagnitudes: microphoneManager.fftMagnitudes ?? [],
                audioLevel: microphoneManager.audioLevel,
                hrvCoherence: healthKitEngine.coherence * 100
            )
        case .mandala:
            MandalaMode(
                audioLevel: microphoneManager.audioLevel,
                frequency: microphoneManager.frequency,
                hrvCoherence: healthKitEngine.coherence * 100,
                heartRate: healthKitEngine.heartRate
            )
        }
    }

    /// Calculate bar height based on audio level
    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / 24.0
        let active = microphoneManager.audioLevel > threshold
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 60

        if active {
            let relativeHeight = CGFloat(microphoneManager.audioLevel - threshold) * 4.0
            return baseHeight + min(relativeHeight * maxHeight, maxHeight)
        }
        return baseHeight
    }

    /// Color for audio bars based on level using design system
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / 24.0
        let active = microphoneManager.audioLevel > threshold

        if active {
            // Gradient from cyan to purple to pink as level increases
            let normalizedIndex = Double(index) / 24.0
            if normalizedIndex < 0.4 {
                return VaporwaveColors.neonCyan
            } else if normalizedIndex < 0.7 {
                return VaporwaveColors.neonPurple
            } else {
                return VaporwaveColors.neonPink
            }
        }
        return VaporwaveColors.textTertiary.opacity(0.3)
    }

    /// Color for coherence score using design system
    private func coherenceColor(_ score: Double) -> Color {
        if score < 40 {
            return VaporwaveColors.coherenceLow
        } else if score < 60 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }

    /// Color for pitch based on frequency range
    private func pitchColor(_ pitch: Float) -> Color {
        if pitch < 100 {
            return VaporwaveColors.neonCyan
        } else if pitch < 200 {
            return VaporwaveColors.lavender
        } else if pitch < 400 {
            return VaporwaveColors.neonPurple
        } else if pitch < 800 {
            return VaporwaveColors.neonPink
        } else {
            return VaporwaveColors.coral
        }
    }

    /// Convert frequency to musical note name (12-tone equal temperament)
    private func musicalNote(_ frequency: Float) -> String {
        guard frequency > 0 else { return "-" }
        let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let semitonesFromA4 = 12.0 * log2(frequency / 440.0)
        let roundedSemitones = Int(round(semitonesFromA4))
        let noteIndex = (9 + roundedSemitones) % 12
        let octave = 4 + (9 + roundedSemitones) / 12
        let positiveNoteIndex = (noteIndex + 12) % 12
        return "\(noteNames[positiveNoteIndex])\(octave)"
    }

    // MARK: - Extracted View Components

    /// Audio metrics display (FFT frequency, level, pitch)
    private var audioMetricsDisplay: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack(spacing: VaporwaveSpacing.xl) {
                // FFT Frequency
                VStack(spacing: VaporwaveSpacing.xs) {
                    Text("\(Int(microphoneManager.frequency))")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(VaporwaveColors.neonCyan)
                        .neonGlow(color: VaporwaveColors.neonCyan, radius: 8)
                    Text("FFT Hz")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .accessibilityLabel("FFT Frequency: \(Int(microphoneManager.frequency)) Hertz")

                // Amplitude
                VStack(spacing: VaporwaveSpacing.xs) {
                    Text(String(format: "%.2f", microphoneManager.audioLevel))
                        .font(VaporwaveTypography.data())
                        .foregroundColor(VaporwaveColors.hrv)
                        .neonGlow(color: VaporwaveColors.hrv, radius: 8)
                    Text("level")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .accessibilityLabel("Audio level: \(String(format: "%.0f", microphoneManager.audioLevel * 100)) percent")
            }
            .padding(.bottom, VaporwaveSpacing.sm)

            // YIN Pitch display
            HStack(spacing: VaporwaveSpacing.lg) {
                VStack(spacing: VaporwaveSpacing.xs) {
                    Text("\(Int(microphoneManager.currentPitch))")
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(pitchColor(microphoneManager.currentPitch))
                    Text("voice pitch (YIN)")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                if microphoneManager.currentPitch > 0 {
                    VStack(spacing: VaporwaveSpacing.xs) {
                        Text(musicalNote(microphoneManager.currentPitch))
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(VaporwaveColors.textPrimary)
                        Text("note")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                }
            }
        }
        .padding(.bottom, VaporwaveSpacing.md)
    }

    /// Bio metrics panel (heart rate, HRV, coherence)
    private var bioMetricsPanel: some View {
        HStack(spacing: VaporwaveSpacing.xl) {
            // Heart Rate
            VStack(spacing: VaporwaveSpacing.xs) {
                Text("\(Int(healthKitEngine.heartRate))")
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.heartRate)
                    .neonGlow(color: VaporwaveColors.heartRate, radius: 6)
                Text("BPM")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("Heart rate: \(Int(healthKitEngine.heartRate)) beats per minute")

            // HRV RMSSD
            VStack(spacing: VaporwaveSpacing.xs) {
                Text(String(format: "%.1f", healthKitEngine.hrvSDNN))
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.hrv)
                    .neonGlow(color: VaporwaveColors.hrv, radius: 6)
                Text("HRV ms")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("Heart rate variability: \(String(format: "%.1f", healthKitEngine.hrvSDNN)) milliseconds")

            // Coherence Score
            VStack(spacing: VaporwaveSpacing.xs) {
                Text("\(Int(healthKitEngine.coherence * 100))")
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(coherenceColor(healthKitEngine.coherence * 100))
                    .neonGlow(color: coherenceColor(healthKitEngine.coherence * 100), radius: 6)
                Text("coherence")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("Coherence score: \(Int(healthKitEngine.coherence * 100))")
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.bottom, VaporwaveSpacing.md)
    }

    /// Audio level bars visualization
    private var audioLevelBars: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            ForEach(0..<24, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor(for: index))
                    .frame(width: 6, height: barHeight(for: index))
            }
        }
        .padding(.bottom, VaporwaveSpacing.md)
        .accessibilityLabel("Audio level meter")
    }

    /// Control buttons row
    private var controlButtonsRow: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Multidimensional Brainwave Entrainment toggle
            controlButton(
                icon: audioEngine.binauralBeatsEnabled ? "waveform.circle.fill" : "waveform.circle",
                label: audioEngine.binauralBeatsEnabled ? "Binaural ON" : "Beats OFF",
                isActive: audioEngine.binauralBeatsEnabled,
                color: VaporwaveColors.neonPurple,
                action: toggleBinauralBeats
            )

            // Main record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(isRecording ? VaporwaveColors.recordingActive : VaporwaveColors.neonCyan)
                        .frame(width: 100, height: 100)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(VaporwaveColors.deepBlack)
                }
                .neonGlow(color: isRecording ? VaporwaveColors.recordingActive : VaporwaveColors.neonCyan, radius: 20)
            }
            .disabled(!microphoneManager.hasPermission && isRecording)
            .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")

            // Spatial audio toggle (if available)
            if audioEngine.spatialAudioEngine != nil {
                controlButton(
                    icon: "airpodspro",
                    label: "Spatial",
                    isActive: audioEngine.spatialAudioEnabled,
                    color: VaporwaveColors.neonCyan,
                    action: { showSpatialControls.toggle() }
                )
            }

            // Recording controls toggle
            controlButton(
                icon: "waveform.circle.fill",
                label: "Studio",
                isActive: recordingEngine.isRecording,
                color: VaporwaveColors.neonPink,
                action: { showRecordingControls.toggle() }
            )

            // Settings toggle
            controlButton(
                icon: "slider.horizontal.3",
                label: "Settings",
                isActive: false,
                color: VaporwaveColors.lavender,
                action: { showBinauralControls.toggle() }
            )
        }
    }

    /// Reusable control button component
    private func controlButton(
        icon: String,
        label: String,
        isActive: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(isActive ? color.opacity(0.3) : VaporwaveColors.deepBlack.opacity(0.5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(isActive ? color : VaporwaveColors.textTertiary, lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isActive ? color : VaporwaveColors.textSecondary)
                }
                .neonGlow(color: isActive ? color : .clear, radius: 10)

                Text(label)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
        }
        .accessibilityLabel("\(label), \(isActive ? "active" : "inactive")")
    }

    /// Spatial audio controls panel
    private var spatialAudioPanel: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                Image(systemName: "airpodspro")
                    .font(.system(size: 18))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text("Spatial Audio")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                Circle()
                    .fill(audioEngine.spatialAudioEnabled ? VaporwaveColors.success : VaporwaveColors.textTertiary)
                    .frame(width: 10, height: 10)
            }

            Toggle(isOn: Binding(
                get: { audioEngine.spatialAudioEnabled },
                set: { _ in audioEngine.toggleSpatialAudio() }
            )) {
                Text("Enable 3D Audio")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: VaporwaveColors.neonCyan))

            if let capabilities = audioEngine.deviceCapabilities {
                VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                    Text("Device: \(capabilities.deviceModel)")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    if capabilities.hasAirPodsConnected {
                        Text("AirPods: \(capabilities.airPodsModel ?? "Unknown")")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }

                    Text(capabilities.supportsASAF ? "ASAF Supported (iOS 18+)" : "ASAF requires iOS 18+ & iPhone 16+")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(capabilities.supportsASAF ? VaporwaveColors.success : VaporwaveColors.warning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(VaporwaveSpacing.lg)
        .glassCard()
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.bottom, VaporwaveSpacing.sm)
    }

    /// Binaural controls panel
    private var binauralControlsPanel: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            Text("Binaural Beat Controls")
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            Picker("Brainwave State", selection: Binding(
                get: { audioEngine.currentBrainwaveState },
                set: { audioEngine.setBrainwaveState($0) }
            )) {
                ForEach(BinauralBeatGenerator.BrainwaveState.allCases, id: \.self) { state in
                    Text(state.rawValue.capitalized).tag(state)
                }
            }
            .pickerStyle(.segmented)

            Text(audioEngine.currentBrainwaveState.description)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)

            VStack(spacing: VaporwaveSpacing.xs) {
                HStack {
                    Text("Volume")
                        .font(VaporwaveTypography.caption())
                    Spacer()
                    Text(String(format: "%.0f%%", audioEngine.binauralAmplitude * 100))
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundColor(VaporwaveColors.textSecondary)

                Slider(value: Binding(
                    get: { audioEngine.binauralAmplitude },
                    set: { audioEngine.setBinauralAmplitude($0) }
                ), in: 0.0...0.6)
                .tint(VaporwaveColors.neonPurple)
            }
        }
        .padding(VaporwaveSpacing.lg)
        .glassCard()
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.bottom, VaporwaveSpacing.sm)
    }

    // MARK: - Actions

    /// Toggle recording on/off with proper error handling
    private func toggleRecording() {
        if isRecording {
            // Stop via AudioEngine (handles all components)
            audioEngine.stop()
            healthKitEngine.stopStreaming()
        } else {
            if microphoneManager.hasPermission {
                // Start via AudioEngine (handles all components)
                audioEngine.start()

                // Start HealthKit monitoring if authorized
                if healthKitEngine.isAuthorized {
                    healthKitEngine.startStreaming()
                }

                // Provide haptic feedback
                #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                #endif
            } else {
                // Request permission and show alert if denied
                microphoneManager.requestPermission()

                // Check again after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !microphoneManager.hasPermission {
                        showPermissionAlert = true
                    }
                }
            }
        }
    }

    /// Toggle Multidimensional Brainwave Entrainment on/off
    private func toggleBinauralBeats() {
        // Use AudioEngine to toggle (handles configuration)
        audioEngine.toggleBinauralBeats()

        // Haptic feedback
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }

    /// Check permissions on launch
    private func checkPermissions() {
        if !microphoneManager.hasPermission {
            microphoneManager.requestPermission()
        }
    }

    /// Open iOS Settings app
    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - iOS 16+ Compatibility

private extension View {
    @ViewBuilder
    func presentationDetentsIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }
}

/// Preview for Xcode canvas
#if DEBUG
#Preview {
    ContentView()
        .environmentObject(MicrophoneManager())
        .environmentObject(AudioEngine())
        .environmentObject(UnifiedHealthKitEngine.shared)
        .environmentObject(RecordingEngine())
}
#endif
