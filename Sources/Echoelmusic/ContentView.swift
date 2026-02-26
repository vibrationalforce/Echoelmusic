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
    @State private var showEEGPanel = false
    @State private var selectedVisualizationMode: VisualizationMode = .particles
    @State private var selectedBrainwaveState: BinauralBeatGenerator.BrainwaveState = .alpha
    @State private var binauralAmplitude: Float = 0.3
    @State private var pulseAnimation = false
    @StateObject private var cymaticsVisualizer = CymaticsVisualizer()
    @StateObject private var eegBridge = EEGSensorBridge.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Breathing Guide State

    /// Current phase of the 4-7-8 breathing cycle
    @State private var breathingPhase: BreathingPhase = .inhale
    /// Scale factor for the breathing guide circle (0-1)
    @State private var breathingScale: CGFloat = 0.3
    /// Opacity for the breathing guide label
    @State private var breathingLabelOpacity: Double = 1.0
    /// Timer that drives the breathing cycle
    @State private var breathingTimer: Timer?
    /// Elapsed seconds within the current breathing phase
    @State private var breathingElapsed: Double = 0.0

    /// Computed property - single source of truth for recording state
    private var isRecording: Bool {
        microphoneManager.isRecording
    }

    /// The normalized coherence value (0-1) for reactive background
    private var coherenceNormalized: Double {
        healthKitEngine.coherence
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background - using design system with coherence-reactive overlay
            VaporwaveGradients.background
                .ignoresSafeArea()

            // Coherence-reactive background overlay
            coherenceReactiveBackground
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: VaporwaveSpacing.xl) {

                // App Title with neon glow
                Text("Echoelmusic")
                    .font(VaporwaveTypography.heroTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .neonGlow(color: isRecording ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan, radius: pulseAnimation ? 20 : 12)
                    .padding(.top, VaporwaveSpacing.xxl)
                    .accessibilityLabel("Echoelmusic - Bio-reactive music application")

                Text("breath \u{2192} sound")
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

                // Breathing guide circle
                if isRecording && healthKitEngine.isAuthorized {
                    breathingGuideView
                        .transition(.opacity.combined(with: .scale))
                }

                // EEG Visualization Panel
                if showEEGPanel && eegBridge.connectionState == .streaming {
                    eegBandPanel
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
        .onDisappear {
            stopBreathingGuide()
        }
        .onChange(of: isRecording) { recording in
            if recording && healthKitEngine.isAuthorized {
                startBreathingGuide()
            } else {
                stopBreathingGuide()
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
        let noteNames = ["C", "C\u{266F}", "D", "D\u{266F}", "E", "F", "F\u{266F}", "G", "G\u{266F}", "A", "A\u{266F}", "B"]
        let semitonesFromA4 = 12.0 * log2(frequency / 440.0)
        let roundedSemitones = Int(round(semitonesFromA4))
        let noteIndex = (9 + roundedSemitones) % 12
        let octave = 4 + (9 + roundedSemitones) / 12
        let positiveNoteIndex = (noteIndex + 12) % 12
        return "\(noteNames[positiveNoteIndex])\(octave)"
    }

    // MARK: - Coherence-Reactive Background

    /// Background overlay that shifts color based on coherence level
    @ViewBuilder
    private var coherenceReactiveBackground: some View {
        if isRecording && healthKitEngine.isAuthorized {
            ZStack {
                // Golden glow when coherence is high (> 0.7)
                if coherenceNormalized > 0.7 {
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.0).opacity(goldenGlowOpacity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 400
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.0), value: coherenceNormalized)
                }

                // Subtle red hints when coherence is low (< 0.3)
                if coherenceNormalized < 0.3 {
                    RadialGradient(
                        colors: [
                            VaporwaveColors.coherenceLow.opacity(redHintOpacity),
                            Color.clear
                        ],
                        center: .bottom,
                        startRadius: 20,
                        endRadius: 350
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.0), value: coherenceNormalized)
                }
            }
        }
    }

    /// Opacity for the golden glow overlay based on how far above 0.7 the coherence is
    private var goldenGlowOpacity: Double {
        let excess = coherenceNormalized - 0.7
        // Map 0.7-1.0 range to 0.0-0.15 opacity
        return min(excess / 0.3, 1.0) * 0.15
    }

    /// Opacity for the red hint overlay based on how far below 0.3 the coherence is
    private var redHintOpacity: Double {
        let deficit = 0.3 - coherenceNormalized
        // Map 0.0-0.3 range to 0.0-0.12 opacity
        return min(deficit / 0.3, 1.0) * 0.12
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

    // MARK: - Breathing Guide

    /// 4-7-8 breathing guide circle that expands and contracts
    private var breathingGuideView: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            Text("Breathing Guide")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .tracking(2)
                .accessibilityLabel("4-7-8 breathing guide")

            ZStack {
                // Outer ring (static reference)
                Circle()
                    .stroke(VaporwaveColors.neonCyan.opacity(0.15), lineWidth: 1)
                    .frame(width: 100, height: 100)

                // Animated breathing circle
                Circle()
                    .fill(breathingCircleColor.opacity(0.25))
                    .frame(
                        width: 100 * breathingScale,
                        height: 100 * breathingScale
                    )
                    .overlay(
                        Circle()
                            .stroke(breathingCircleColor.opacity(0.6), lineWidth: 2)
                    )
                    .neonGlow(color: breathingCircleColor, radius: 8 * breathingScale)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: breathingPhaseDuration),
                        value: breathingScale
                    )

                // Phase label
                Text(breathingPhase.label)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .opacity(breathingLabelOpacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: breathingPhase)
            }
            .frame(width: 100, height: 100)
            .accessibilityLabel("Breathing guide: \(breathingPhase.accessibilityLabel)")

            // Breathing rate from HealthKit
            if healthKitEngine.respiratoryData.breathingRate > 0 {
                Text("\(Int(healthKitEngine.respiratoryData.breathingRate)) breaths/min")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .accessibilityLabel("Current breathing rate: \(Int(healthKitEngine.respiratoryData.breathingRate)) breaths per minute")
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.bottom, VaporwaveSpacing.sm)
    }

    /// Color for the breathing circle based on the current phase
    private var breathingCircleColor: Color {
        switch breathingPhase {
        case .inhale:
            return VaporwaveColors.neonCyan
        case .hold:
            return VaporwaveColors.lavender
        case .exhale:
            return VaporwaveColors.neonPurple
        }
    }

    /// Duration of the current breathing phase in seconds
    private var breathingPhaseDuration: Double {
        switch breathingPhase {
        case .inhale: return 4.0
        case .hold: return 7.0
        case .exhale: return 8.0
        }
    }

    // MARK: - EEG Band Visualization

    /// Compact EEG band visualization panel with meditation/focus/flow scores
    private var eegBandPanel: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Header row
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.neonPurple)

                Text("EEG Bands")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .tracking(1)

                Spacer()

                if let device = eegBridge.connectedDevice {
                    Text(device.rawValue)
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                // Signal quality dot
                Circle()
                    .fill(eegSignalQualityColor)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Signal quality: \(Int(eegBridge.signalQuality * 100)) percent")
            }

            // Compact band bars
            HStack(spacing: VaporwaveSpacing.xs) {
                eegBandBar(label: "\u{03B4}", value: eegBridge.currentBands.delta, maxValue: 50, color: VaporwaveColors.neonPurple)
                eegBandBar(label: "\u{03B8}", value: eegBridge.currentBands.theta, maxValue: 50, color: VaporwaveColors.lavender)
                eegBandBar(label: "\u{03B1}", value: eegBridge.currentBands.alpha, maxValue: 50, color: VaporwaveColors.neonCyan)
                eegBandBar(label: "\u{03B2}", value: eegBridge.currentBands.beta, maxValue: 50, color: VaporwaveColors.coherenceMedium)
                eegBandBar(label: "\u{03B3}", value: eegBridge.currentBands.gamma, maxValue: 50, color: VaporwaveColors.coral)
            }
            .frame(height: 60)
            .accessibilityLabel("EEG frequency bands: Delta \(Int(eegBridge.currentBands.delta)), Theta \(Int(eegBridge.currentBands.theta)), Alpha \(Int(eegBridge.currentBands.alpha)), Beta \(Int(eegBridge.currentBands.beta)), Gamma \(Int(eegBridge.currentBands.gamma))")

            // Dominant band label
            Text("Dominant: \(eegBridge.currentBands.dominantBand)")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)

            // Meditation, Focus, Flow scores row
            HStack(spacing: VaporwaveSpacing.lg) {
                eegScoreView(
                    label: "Meditation",
                    value: eegBridge.meditationScore,
                    color: VaporwaveColors.neonPurple
                )
                eegScoreView(
                    label: "Focus",
                    value: eegBridge.focusScore,
                    color: VaporwaveColors.neonCyan
                )
                eegScoreView(
                    label: "Flow",
                    value: eegBridge.flowScore,
                    color: VaporwaveColors.coherenceHigh
                )
            }

            // Disclaimer
            Text("Creative use only. Not a medical device.")
                .font(.system(size: 8, weight: .light))
                .foregroundColor(VaporwaveColors.textTertiary.opacity(0.6))
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.bottom, VaporwaveSpacing.sm)
    }

    /// Single vertical bar for an EEG band
    private func eegBandBar(label: String, value: Double, maxValue: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            // Value
            Text("\(Int(value))")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(color)

            // Vertical bar
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: 12,
                            height: geometry.size.height * min(value / maxValue, 1.0)
                        )
                        .neonGlow(color: color, radius: 4)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: value)
                }
            }

            // Greek letter label
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    /// Circular score indicator for meditation/focus/flow
    private func eegScoreView(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            ZStack {
                Circle()
                    .stroke(VaporwaveColors.textTertiary.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: value)

                Text("\(Int(value * 100))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            .frame(width: 36, height: 36)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .accessibilityLabel("\(label) score: \(Int(value * 100)) percent")
    }

    /// Color for the EEG signal quality indicator
    private var eegSignalQualityColor: Color {
        if eegBridge.signalQuality > 0.7 {
            return VaporwaveColors.coherenceHigh
        } else if eegBridge.signalQuality > 0.4 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceLow
        }
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

            // EEG button
            controlButton(
                icon: "brain.head.profile",
                label: showEEGPanel ? "EEG ON" : "EEG",
                isActive: showEEGPanel && eegBridge.connectionState == .streaming,
                color: VaporwaveColors.lavender,
                action: toggleEEG
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

    /// Toggle EEG panel and start/stop simulation if needed
    private func toggleEEG() {
        showEEGPanel.toggle()

        if showEEGPanel {
            if eegBridge.connectionState == .disconnected {
                // Start simulation for demo; in production, scan for real devices
                eegBridge.startSimulation()
                log.biofeedback("EEG panel activated, started simulation")
            }
        } else {
            if eegBridge.connectedDevice == .simulator {
                eegBridge.stopSimulation()
                log.biofeedback("EEG panel deactivated, stopped simulation")
            }
        }
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

    // MARK: - Breathing Guide Logic

    /// Start the 4-7-8 breathing guide cycle
    private func startBreathingGuide() {
        guard breathingTimer == nil else { return }
        breathingPhase = .inhale
        breathingElapsed = 0.0
        breathingScale = 0.3
        breathingLabelOpacity = 1.0

        log.biofeedback("Breathing guide started (4-7-8 pattern)")

        // Kick off the first phase transition
        advanceBreathingPhase()

        // Tick every 0.1s to track elapsed time and advance phases
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            Task { @MainActor in
                self.breathingElapsed += 0.1
                if self.breathingElapsed >= self.breathingPhaseDuration {
                    self.breathingElapsed = 0.0
                    // Advance to next phase
                    switch self.breathingPhase {
                    case .inhale:
                        self.breathingPhase = .hold
                    case .hold:
                        self.breathingPhase = .exhale
                    case .exhale:
                        self.breathingPhase = .inhale
                    }
                    self.advanceBreathingPhase()
                }
            }
        }
    }

    /// Stop the breathing guide
    private func stopBreathingGuide() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        breathingPhase = .inhale
        breathingScale = 0.3
    }

    /// Apply the scale for the current breathing phase
    private func advanceBreathingPhase() {
        switch breathingPhase {
        case .inhale:
            // Expand circle over 4 seconds
            breathingScale = 1.0
        case .hold:
            // Stay fully expanded for 7 seconds
            breathingScale = 1.0
        case .exhale:
            // Contract circle over 8 seconds
            breathingScale = 0.3
        }
    }
}

// MARK: - Breathing Phase Enum

/// Phases in the 4-7-8 breathing technique
enum BreathingPhase: String, CaseIterable {
    case inhale
    case hold
    case exhale

    /// Display label
    var label: String {
        switch self {
        case .inhale: return "Breathe In"
        case .hold: return "Hold"
        case .exhale: return "Breathe Out"
        }
    }

    /// Accessibility description
    var accessibilityLabel: String {
        switch self {
        case .inhale: return "Inhale for 4 seconds"
        case .hold: return "Hold breath for 7 seconds"
        case .exhale: return "Exhale for 8 seconds"
        }
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
