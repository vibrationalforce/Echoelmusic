// HRVTrainingView.swift
// Echoelmusic - Focused HRV Training Session UI
//
// Simple, clean interface for HRV biofeedback training.
// Three data sources: Camera PPG, Apple Watch, Oura Ring (via HealthKit)
//
// Flow:
// 1. Choose input source (camera / watch / Oura)
// 2. If camera: place finger → calibrate → measure
// 3. Session starts: coherence circle + waveform + sound
// 4. Customize sound via bottom sheet
// 5. Session ends: summary with metrics
//
// ============================================================================
// NOT A MEDICAL DEVICE — For wellness/creative purposes only.
// ============================================================================

import SwiftUI
import Combine

// MARK: - Input Source

/// Biometric data source for HRV training
enum HRVInputSource: String, CaseIterable {
    case camera = "Camera"
    case appleWatch = "Apple Watch"
    case ouraRing = "Oura Ring"

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .appleWatch: return "applewatch"
        case .ouraRing: return "circle.circle"
        }
    }

    var description: String {
        switch self {
        case .camera: return "Finger on camera lens"
        case .appleWatch: return "Real-time from Apple Watch"
        case .ouraRing: return "Daily HRV via HealthKit"
        }
    }
}

// MARK: - Training View

/// Main HRV training session view
struct HRVTrainingView: View {
    @StateObject private var viewModel = HRVTrainingViewModel()
    @State private var showSoundSettings = false
    @State private var showSourcePicker = false

    var body: some View {
        ZStack {
            // Background gradient based on coherence
            backgroundGradient

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Main content based on state
                switch viewModel.sessionState {
                case .selectingSource:
                    sourceSelectionView
                case .preparingInput:
                    preparingInputView
                case .running:
                    sessionView
                case .completed:
                    sessionSummaryView
                }

                Spacer()

                // Bottom controls
                if viewModel.sessionState == .running {
                    bottomControls
                }
            }
            .padding()
        }
        .sheet(isPresented: $showSoundSettings) {
            SoundSettingsSheet(engine: viewModel.soundEngine)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let coherence = viewModel.coherence
        let topColor: Color
        let bottomColor: Color

        if coherence > 0.6 {
            // High coherence: warm gold/green
            topColor = Color(red: 0.1, green: 0.15, blue: 0.1)
            bottomColor = Color(red: 0.05, green: 0.1, blue: 0.05)
        } else if coherence > 0.4 {
            // Medium: calm blue
            topColor = Color(red: 0.08, green: 0.1, blue: 0.18)
            bottomColor = Color(red: 0.04, green: 0.06, blue: 0.12)
        } else {
            // Low: neutral dark
            topColor = Color(red: 0.1, green: 0.1, blue: 0.12)
            bottomColor = Color(red: 0.05, green: 0.05, blue: 0.08)
        }

        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 2.0), value: coherence > 0.6)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Duration
            if viewModel.sessionState == .running {
                Text(viewModel.formattedDuration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Signal quality indicator
            if viewModel.inputSource == .camera && viewModel.sessionState == .running {
                HStack(spacing: 4) {
                    signalBars
                    Text(viewModel.signalQuality.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal)
    }

    private var signalBars: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar < viewModel.signalBarsCount ? Color.green : Color.white.opacity(0.2))
                    .frame(width: 3, height: CGFloat(6 + bar * 3))
            }
        }
    }

    // MARK: - Source Selection

    private var sourceSelectionView: some View {
        VStack(spacing: 32) {
            Text("HRV Training")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)

            Text("Choose your heart rate source")
                .font(.body)
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 16) {
                ForEach(HRVInputSource.allCases, id: \.rawValue) { source in
                    Button {
                        viewModel.selectSource(source)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: source.icon)
                                .font(.title2)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.rawValue)
                                    .font(.headline)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal)

            // Disclaimer
            Text("Not a medical device. For wellness purposes only.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 16)
        }
    }

    // MARK: - Preparing Input

    private var preparingInputView: some View {
        VStack(spacing: 24) {
            if viewModel.inputSource == .camera {
                cameraPreparationView
            } else {
                healthKitPreparationView
            }
        }
    }

    private var cameraPreparationView: some View {
        VStack(spacing: 24) {
            // Finger placement illustration
            ZStack {
                Circle()
                    .fill(viewModel.ppgEngine.signalStrength > 0.3
                          ? Color.red.opacity(0.3)
                          : Color.white.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.ppgEngine.signalStrength > 0.3)

                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.6))
            }

            Text("Place your finger over the camera lens")
                .font(.headline)
                .foregroundColor(.white)

            Text("Cover the camera and flash completely.\nHold still for accurate measurement.")
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // Signal strength meter
            if viewModel.ppgEngine.state != .idle {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.ppgEngine.signalStrength)
                        .tint(viewModel.ppgEngine.signalQuality.isUsable ? .green : .orange)

                    Text(viewModel.ppgEngine.signalQuality.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 40)
            }

            if viewModel.ppgEngine.state == .measuring {
                Button("Start Session") {
                    viewModel.startSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green.opacity(0.8))
            }
        }
    }

    private var healthKitPreparationView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Connecting to \(viewModel.inputSource.rawValue)...")
                .font(.headline)
                .foregroundColor(.white)

            if viewModel.healthKitEngine.authState == .denied {
                Text("HealthKit access denied.\nPlease enable in Settings > Privacy > Health.")
                    .font(.body)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Session View

    private var sessionView: some View {
        VStack(spacing: 24) {
            // Coherence circle
            coherenceCircle

            // Metrics row
            metricsRow

            // PPG waveform (camera mode only)
            if viewModel.inputSource == .camera {
                ppgWaveformView
            }

            // Coherence history
            coherenceHistoryView
        }
    }

    private var coherenceCircle: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [coherenceColor.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .animation(.easeInOut(duration: 1.5), value: viewModel.coherence)

            // Ring
            Circle()
                .stroke(coherenceColor.opacity(0.6), lineWidth: 4)
                .frame(width: 140, height: 140)

            // Progress ring
            Circle()
                .trim(from: 0, to: viewModel.coherence)
                .stroke(coherenceColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: viewModel.coherence)

            // Center content
            VStack(spacing: 4) {
                Text("\(Int(viewModel.coherence * 100))")
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .foregroundColor(.white)

                Text("Coherence")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var coherenceColor: Color {
        let c = viewModel.coherence
        if c > 0.6 {
            return Color(red: 0.2, green: 0.8, blue: 0.4)  // Green
        } else if c > 0.4 {
            return Color(red: 0.3, green: 0.6, blue: 0.9)  // Blue
        } else {
            return Color(red: 0.9, green: 0.6, blue: 0.3)  // Orange
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 24) {
            metricItem(value: "\(Int(viewModel.heartRate))", unit: "BPM", label: "Heart Rate")
            metricItem(value: String(format: "%.0f", viewModel.hrvSDNN), unit: "ms", label: "HRV (SDNN)")
            metricItem(value: String(format: "%.1f", viewModel.breathingRate), unit: "/min", label: "Breathing")
        }
    }

    private func metricItem(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    /// PPG waveform visualization
    private var ppgWaveformView: some View {
        GeometryReader { geo in
            let waveform = viewModel.ppgWaveform
            if waveform.count > 1 {
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    let maxAmp = waveform.map { abs($0) }.max() ?? 1.0
                    let scale = maxAmp > 0 ? Float(height / 2) / maxAmp : 1.0

                    for (index, sample) in waveform.enumerated() {
                        let x = CGFloat(index) / CGFloat(waveform.count - 1) * width
                        let y = height / 2 - CGFloat(sample * scale)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
            }
        }
        .frame(height: 60)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    /// Coherence history chart
    private var coherenceHistoryView: some View {
        GeometryReader { geo in
            let history = viewModel.coherenceHistory
            if history.count > 1 {
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height

                    for (index, value) in history.enumerated() {
                        let x = CGFloat(index) / CGFloat(history.count - 1) * width
                        let y = height - CGFloat(value) * height

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.orange, .blue, .green],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: 2
                )
            }
        }
        .frame(height: 50)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Sound settings
            Button {
                showSoundSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            // Stop button
            Button {
                viewModel.stopSession()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red.opacity(0.6))
                    .clipShape(Circle())
            }

            // Mute toggle
            Button {
                viewModel.toggleMute()
            } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Session Summary

    private var sessionSummaryView: some View {
        VStack(spacing: 24) {
            Text("Session Complete")
                .font(.title2)
                .foregroundColor(.white)

            // Summary metrics
            VStack(spacing: 16) {
                summaryRow(label: "Duration", value: viewModel.formattedDuration)
                summaryRow(label: "Avg Coherence", value: "\(Int(viewModel.avgCoherence * 100))%")
                summaryRow(label: "Peak Coherence", value: "\(Int(viewModel.peakCoherence * 100))%")
                summaryRow(label: "Avg Heart Rate", value: "\(Int(viewModel.avgHeartRate)) BPM")
                summaryRow(label: "HRV (SDNN)", value: String(format: "%.1f ms", viewModel.avgHRV))
                summaryRow(label: "Time in High Coherence", value: "\(Int(viewModel.timeInHighCoherence))%")
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)

            Button("New Session") {
                viewModel.resetSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue.opacity(0.6))
        }
        .padding(.horizontal)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Sound Settings Sheet

/// Bottom sheet for customizing sound during session
struct SoundSettingsSheet: View {
    @ObservedObject var engine: HRVSoundscapeEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Presets
                Section("Presets") {
                    Button("Default") { engine.preferences = .default }
                    Button("Deep Calm") { engine.preferences = .deepCalm }
                    Button("Crystal Focus") { engine.preferences = .crystalFocus }
                    Button("Tibetan Meditation") { engine.preferences = .tibetanMeditation }
                }

                // Timbre
                Section("Sound Character") {
                    Picker("Timbre", selection: $engine.preferences.timbre) {
                        ForEach(SoundTimbre.allCases, id: \.self) { timbre in
                            Text(timbre.displayName).tag(timbre)
                        }
                    }

                    HStack {
                        Text("Base Frequency")
                        Spacer()
                        Text("\(Int(engine.preferences.carrierFrequency)) Hz")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $engine.preferences.carrierFrequency, in: 396...528, step: 1)
                }

                // Layers
                Section("Layer Volumes") {
                    sliderRow("Pad / Drone", value: $engine.preferences.padVolume)
                    sliderRow("Entrainment Beats", value: $engine.preferences.beatsVolume)
                    Toggle("Beats Enabled", isOn: $engine.preferences.beatsEnabled)
                    sliderRow("Breathing Guide", value: $engine.preferences.breathingVolume)
                    sliderRow("Harmonic Overtones", value: $engine.preferences.harmonicsVolume)
                }

                // Beats
                Section("Brainwave Entrainment") {
                    HStack {
                        Text("Beat Frequency")
                        Spacer()
                        Text(String(format: "%.1f Hz", engine.preferences.beatFrequency))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $engine.preferences.beatFrequency, in: 1...40, step: 0.5)

                    HStack {
                        Text("Quick Select")
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        beatPresetButton("Delta\n2 Hz", freq: 2)
                        beatPresetButton("Theta\n6 Hz", freq: 6)
                        beatPresetButton("Alpha\n10 Hz", freq: 10)
                        beatPresetButton("Beta\n20 Hz", freq: 20)
                    }
                }

                // Breathing
                Section("Breathing Guide") {
                    Picker("Style", selection: $engine.preferences.breathingGuide) {
                        ForEach(BreathingGuideStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    HStack {
                        Text("Target Rate")
                        Spacer()
                        Text(String(format: "%.1f breaths/min", engine.preferences.targetBreathingRate))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $engine.preferences.targetBreathingRate, in: 4...12, step: 0.5)
                }

                // Spatial & Effects
                Section("Spatial & Effects") {
                    sliderRow("Stereo Width", value: $engine.preferences.spatialWidth)
                    sliderRow("Reverb", value: $engine.preferences.reverbAmount)
                    sliderRow("Bio-Reactivity", value: $engine.preferences.bioReactivity)
                    sliderRow("Master Volume", value: $engine.preferences.masterVolume)
                }
            }
            .navigationTitle("Sound Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: 0...1)
        }
    }

    private func beatPresetButton(_ label: String, freq: Float) -> some View {
        Button {
            engine.preferences.beatFrequency = freq
        } label: {
            Text(label)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    abs(engine.preferences.beatFrequency - freq) < 0.5
                    ? Color.accentColor.opacity(0.3)
                    : Color.secondary.opacity(0.1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session State

enum HRVSessionState {
    case selectingSource
    case preparingInput
    case running
    case completed
}

// MARK: - View Model

@MainActor
final class HRVTrainingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var sessionState: HRVSessionState = .selectingSource
    @Published var inputSource: HRVInputSource = .camera
    @Published var isMuted = false

    // Live metrics
    @Published var coherence: Double = 0.5
    @Published var heartRate: Double = 70
    @Published var hrvSDNN: Double = 50
    @Published var breathingRate: Double = 12
    @Published var duration: TimeInterval = 0

    // Waveform data
    @Published var ppgWaveform: [Float] = []
    @Published var coherenceHistory: [Double] = []

    // Signal quality (camera mode)
    @Published var signalQuality: PPGSignalQuality = .noSignal

    // Summary metrics
    var avgCoherence: Double = 0
    var peakCoherence: Double = 0
    var avgHeartRate: Double = 0
    var avgHRV: Double = 0
    var timeInHighCoherence: Double = 0

    // MARK: - Engines

    let ppgEngine = CameraPPGEngine()
    let healthKitEngine = UnifiedHealthKitEngine.shared
    let soundEngine = HRVSoundscapeEngine()

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var coherenceAccumulator: [Double] = []
    private var heartRateAccumulator: [Double] = []
    private var hrvAccumulator: [Double] = []
    private var highCoherenceFrames = 0
    private var totalFrames = 0

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var signalBarsCount: Int {
        switch signalQuality {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .noSignal: return 0
        }
    }

    init() {
        setupBindings()
    }

    // MARK: - Source Selection

    func selectSource(_ source: HRVInputSource) {
        inputSource = source
        sessionState = .preparingInput

        switch source {
        case .camera:
            ppgEngine.startMeasurement()
        case .appleWatch, .ouraRing:
            // Request HealthKit authorization and start streaming
            Task {
                try? await healthKitEngine.requestAuthorization()
                if healthKitEngine.isAuthorized {
                    healthKitEngine.startStreaming()
                    startSession()
                }
            }
        }
    }

    // MARK: - Session Control

    func startSession() {
        sessionState = .running
        duration = 0
        coherenceAccumulator.removeAll()
        heartRateAccumulator.removeAll()
        hrvAccumulator.removeAll()
        highCoherenceFrames = 0
        totalFrames = 0
        coherenceHistory.removeAll()

        // Start sound
        soundEngine.start()

        // Start session timer (1 Hz update)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.duration += 1
            self.updateMetrics()
        }
    }

    func stopSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil

        // Stop input
        if inputSource == .camera {
            ppgEngine.stopMeasurement()
        } else {
            healthKitEngine.stopStreaming()
        }

        // Stop sound
        soundEngine.stop()

        // Calculate summary
        calculateSummary()

        sessionState = .completed
    }

    func resetSession() {
        sessionState = .selectingSource
        coherence = 0.5
        heartRate = 70
        hrvSDNN = 50
        breathingRate = 12
        ppgWaveform.removeAll()
        coherenceHistory.removeAll()
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            soundEngine.stop()
        } else {
            soundEngine.start()
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Camera PPG → ViewModel
        ppgEngine.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                if self?.inputSource == .camera && hr > 0 {
                    self?.heartRate = hr
                }
            }
            .store(in: &cancellables)

        ppgEngine.$ppgWaveform
            .receive(on: DispatchQueue.main)
            .assign(to: &$ppgWaveform)

        ppgEngine.$signalQuality
            .receive(on: DispatchQueue.main)
            .assign(to: &$signalQuality)

        // Camera R-R intervals → HealthKit Engine for coherence calculation
        ppgEngine.onRRIntervalDetected = { [weak self] rrInterval in
            guard let self = self else { return }
            // Feed R-R interval into the coherence calculator
            self.healthKitEngine.injectRRInterval(rrInterval)
        }

        // HealthKit Engine → ViewModel
        healthKitEngine.$coherence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] c in
                self?.coherence = c
                self?.soundEngine.updateBiometrics(
                    coherence: c,
                    heartRate: self?.heartRate ?? 70,
                    breathingRate: self?.breathingRate ?? 12
                )
            }
            .store(in: &cancellables)

        healthKitEngine.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                if self?.inputSource != .camera {
                    self?.heartRate = hr
                }
            }
            .store(in: &cancellables)

        healthKitEngine.$hrvSDNN
            .receive(on: DispatchQueue.main)
            .assign(to: &$hrvSDNN)

        healthKitEngine.$breathingRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$breathingRate)
    }

    // MARK: - Metrics Update

    private func updateMetrics() {
        totalFrames += 1
        coherenceAccumulator.append(coherence)
        heartRateAccumulator.append(heartRate)
        hrvAccumulator.append(hrvSDNN)

        if coherence > 0.6 {
            highCoherenceFrames += 1
        }

        // Keep last 5 minutes of coherence history
        coherenceHistory.append(coherence)
        if coherenceHistory.count > 300 {
            coherenceHistory.removeFirst()
        }
    }

    private func calculateSummary() {
        guard !coherenceAccumulator.isEmpty else { return }

        avgCoherence = coherenceAccumulator.reduce(0, +) / Double(coherenceAccumulator.count)
        peakCoherence = coherenceAccumulator.max() ?? 0
        avgHeartRate = heartRateAccumulator.isEmpty ? 0 :
            heartRateAccumulator.reduce(0, +) / Double(heartRateAccumulator.count)
        avgHRV = hrvAccumulator.isEmpty ? 0 :
            hrvAccumulator.reduce(0, +) / Double(hrvAccumulator.count)
        timeInHighCoherence = totalFrames > 0 ?
            Double(highCoherenceFrames) / Double(totalFrames) * 100 : 0
    }
}
