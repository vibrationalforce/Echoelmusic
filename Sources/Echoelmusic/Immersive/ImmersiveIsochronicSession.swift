// ImmersiveIsochronicSession.swift
// Echoelmusic - Unified Immersive Isochronic Experience
//
// Combines isochronic/binaural audio with immersive visuals and bio-reactive modulation
// for complete brainwave entrainment experiences in VR/AR environments.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine
import AVFoundation

// MARK: - Session Configuration

/// Immersive isochronic session preset
public enum IsochronicPreset: String, CaseIterable, Identifiable {
    case deepMeditation = "Deep Meditation"
    case focusFlow = "Focus Flow"
    case creativeDream = "Creative Dream"
    case relaxationPortal = "Relaxation Portal"
    case sleepJourney = "Sleep Journey"
    case energyBoost = "Energy Boost"
    case quantumCoherence = "Quantum Coherence"
    case sacredGeometry = "Sacred Geometry"

    public var id: String { rawValue }

    /// Target brainwave frequency in Hz
    public var targetFrequency: Float {
        switch self {
        case .deepMeditation: return 6.0   // Theta
        case .focusFlow: return 14.0       // Low Beta
        case .creativeDream: return 7.83   // Schumann Resonance
        case .relaxationPortal: return 10.0 // Alpha
        case .sleepJourney: return 2.0     // Delta
        case .energyBoost: return 20.0     // Beta
        case .quantumCoherence: return 40.0 // Gamma
        case .sacredGeometry: return 7.83  // Schumann
        }
    }

    /// Carrier frequency for the isochronic tone
    public var carrierFrequency: Float {
        switch self {
        case .sleepJourney, .deepMeditation: return 432.0  // Solfeggio
        case .energyBoost, .focusFlow: return 528.0        // DNA repair frequency
        case .quantumCoherence: return 639.0               // Heart chakra
        default: return 440.0                               // Standard
        }
    }

    /// Visual mode for this preset
    public var visualMode: IsochronicVisualMode {
        switch self {
        case .deepMeditation: return .breathingMandala
        case .focusFlow: return .flowTunnel
        case .creativeDream: return .fractalDream
        case .relaxationPortal: return .coherenceField
        case .sleepJourney: return .gentleWaves
        case .energyBoost: return .energyParticles
        case .quantumCoherence: return .quantumField
        case .sacredGeometry: return .sacredPatterns
        }
    }

    /// Session duration suggestion in seconds
    public var suggestedDuration: TimeInterval {
        switch self {
        case .sleepJourney: return 1800      // 30 min
        case .deepMeditation: return 1200    // 20 min
        case .focusFlow: return 1500         // 25 min
        case .energyBoost: return 300        // 5 min
        default: return 900                   // 15 min
        }
    }

    /// Description of the experience
    public var description: String {
        switch self {
        case .deepMeditation:
            return "Enter a deep meditative state with theta waves and breathing mandalas"
        case .focusFlow:
            return "Enhance concentration and productivity with focused beta entrainment"
        case .creativeDream:
            return "Unlock creative potential with Schumann resonance and fractal visuals"
        case .relaxationPortal:
            return "Relax deeply with alpha waves and coherence field visualization"
        case .sleepJourney:
            return "Prepare for restful sleep with delta waves and gentle ocean visuals"
        case .energyBoost:
            return "Quick energizing session with beta waves and particle dynamics"
        case .quantumCoherence:
            return "Experience peak awareness with gamma entrainment and quantum visuals"
        case .sacredGeometry:
            return "Connect with universal patterns through sacred geometry and Schumann resonance"
        }
    }
}

/// Visual modes for immersive isochronic sessions
public enum IsochronicVisualMode: String, CaseIterable {
    case breathingMandala = "Breathing Mandala"
    case flowTunnel = "Flow Tunnel"
    case fractalDream = "Fractal Dream"
    case coherenceField = "Coherence Field"
    case gentleWaves = "Gentle Waves"
    case energyParticles = "Energy Particles"
    case quantumField = "Quantum Field"
    case sacredPatterns = "Sacred Patterns"
    case biophotonAura = "Biophoton Aura"
    case cosmicNebula = "Cosmic Nebula"
}

/// Audio mode for isochronic/binaural delivery
public enum IsochronicAudioMode: String, CaseIterable {
    case isochronic = "Isochronic Tones"      // Works on speakers
    case binaural = "Binaural Beats"           // Requires headphones
    case monaural = "Monaural Beats"           // Hybrid approach
    case hybrid = "Hybrid (Auto-detect)"       // Auto-selects based on output

    public var requiresHeadphones: Bool {
        self == .binaural
    }
}

// MARK: - Bio-Reactive Parameters

/// Bio-reactive modulation settings
public struct BioModulationConfig {
    /// How much HRV coherence affects visual intensity (0-1)
    public var coherenceToVisualIntensity: Float = 0.7

    /// How much heart rate affects entrainment tempo (0-1)
    public var heartRateToTempo: Float = 0.3

    /// How much breathing affects visual scale (0-1)
    public var breathingToVisualScale: Float = 0.5

    /// Enable automatic frequency adjustment based on coherence
    public var adaptiveFrequency: Bool = true

    /// Target coherence level (0-1)
    public var targetCoherence: Float = 0.7

    public init() {}
}

// MARK: - Session State

/// Current state of an immersive isochronic session
public struct IsochronicSessionState {
    public var isActive: Bool = false
    public var currentPhase: SessionPhase = .preparation
    public var elapsedTime: TimeInterval = 0
    public var currentFrequency: Float = 10.0
    public var currentCoherence: Float = 0.5
    public var visualIntensity: Float = 0.5
    public var audioLevel: Float = 0.7
    public var entrainmentScore: Float = 0.0  // 0-100

    public enum SessionPhase: String {
        case preparation = "Preparation"
        case rampUp = "Ramp Up"
        case entrainment = "Entrainment"
        case peak = "Peak Experience"
        case rampDown = "Ramp Down"
        case integration = "Integration"
        case complete = "Complete"
    }
}

// MARK: - Main Engine

/// Unified Immersive Isochronic Session Engine
///
/// Combines:
/// - Isochronic/Binaural beat generation
/// - Immersive visual rendering (VR/AR ready)
/// - Bio-reactive parameter modulation
/// - Circadian rhythm awareness
/// - Session management and analytics
///
/// DISCLAIMER: This feature is for relaxation and creative purposes only.
/// It is NOT a medical device and makes no health claims.
/// Consult a healthcare professional before use if you have epilepsy or seizure disorders.
@MainActor
public final class ImmersiveIsochronicSession: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var state = IsochronicSessionState()
    @Published public private(set) var currentPreset: IsochronicPreset = .relaxationPortal
    @Published public var audioMode: IsochronicAudioMode = .hybrid
    @Published public var bioModulation = BioModulationConfig()
    @Published public private(set) var isHeadphonesConnected: Bool = false

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var toneGenerator: AVAudioSourceNode?
    private var carrierPhase: Float = 0
    private var modulationPhase: Float = 0

    // MARK: - Visual State

    @Published public var visualMode: IsochronicVisualMode = .coherenceField
    @Published public var visualParameters = VisualParameters()

    public struct VisualParameters {
        public var hue: Float = 0.6           // 0-1 (blue-ish default)
        public var saturation: Float = 0.7
        public var brightness: Float = 0.8
        public var complexity: Float = 0.5
        public var pulseIntensity: Float = 0.5
        public var rotationSpeed: Float = 0.1
        public var scale: Float = 1.0
        public var particleCount: Int = 100
    }

    // MARK: - Bio Input

    @Published public var bioInput = BioInput()

    public struct BioInput {
        public var heartRate: Float = 70       // BPM
        public var hrvCoherence: Float = 0.5   // 0-1
        public var breathingRate: Float = 12   // breaths/min
        public var breathPhase: Float = 0.5    // 0-1 (0=exhale, 1=inhale)
    }

    // MARK: - Session Analytics

    @Published public private(set) var analytics = SessionAnalytics()

    public struct SessionAnalytics {
        public var totalDuration: TimeInterval = 0
        public var averageCoherence: Float = 0
        public var peakCoherence: Float = 0
        public var coherenceHistory: [Float] = []
        public var entrainmentAchieved: Bool = false
        public var entrainmentDuration: TimeInterval = 0
    }

    // MARK: - Timers

    private var sessionTimer: Timer?
    private var updateTimer: Timer?
    private let sampleRate: Double = 48000

    // MARK: - Initialization

    public init() {
        setupAudioEngine()
        detectHeadphones()
    }

    // MARK: - Audio Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine else { return }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            log.error("Failed to create AVAudioFormat for immersive session")
            return
        }

        // Create tone generator node
        toneGenerator = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSample()

                // Stereo output
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }

            return noErr
        }

        if let toneGenerator = toneGenerator {
            audioEngine.attach(toneGenerator)
            audioEngine.connect(toneGenerator, to: audioEngine.mainMixerNode, format: format)
        }
    }

    private func generateSample() -> Float {
        guard state.isActive else { return 0 }

        let carrierFreq = currentPreset.carrierFrequency
        let modulationFreq = state.currentFrequency

        // Advance phases
        let carrierIncrement = Float(2.0 * Double.pi * Double(carrierFreq) / sampleRate)
        let modulationIncrement = Float(2.0 * Double.pi * Double(modulationFreq) / sampleRate)

        carrierPhase += carrierIncrement
        modulationPhase += modulationIncrement

        // Wrap phases
        if carrierPhase > Float.pi * 2 { carrierPhase -= Float.pi * 2 }
        if modulationPhase > Float.pi * 2 { modulationPhase -= Float.pi * 2 }

        // Generate based on audio mode
        let effectiveMode = resolveAudioMode()
        var sample: Float = 0

        switch effectiveMode {
        case .isochronic:
            // Isochronic: amplitude modulated tone
            let carrier = sin(carrierPhase)
            let envelope = (sin(modulationPhase) + 1) / 2  // 0-1 range
            let sharpEnvelope = pow(envelope, 2)  // Sharper pulses
            sample = carrier * sharpEnvelope

        case .binaural:
            // Binaural: different frequencies per ear (mono mix for now)
            let leftFreq = carrierFreq - modulationFreq / 2
            let rightFreq = carrierFreq + modulationFreq / 2
            let leftPhase = Float(2.0 * Double.pi * Double(leftFreq) / sampleRate)
            let rightPhase = Float(2.0 * Double.pi * Double(rightFreq) / sampleRate)
            sample = (sin(carrierPhase + leftPhase) + sin(carrierPhase + rightPhase)) / 2

        case .monaural:
            // Monaural: beat created in the signal itself
            let beat = (sin(modulationPhase) + 1) / 2
            sample = sin(carrierPhase) * beat

        case .hybrid:
            // Default to isochronic
            let carrier = sin(carrierPhase)
            let envelope = (sin(modulationPhase) + 1) / 2
            sample = carrier * envelope
        }

        // Apply volume
        return sample * state.audioLevel * 0.3  // Master volume reduction
    }

    private func resolveAudioMode() -> IsochronicAudioMode {
        if audioMode == .hybrid {
            return isHeadphonesConnected ? .binaural : .isochronic
        }
        return audioMode
    }

    private func detectHeadphones() {
        let route = AVAudioSession.sharedInstance().currentRoute
        isHeadphonesConnected = route.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP
        }
    }

    // MARK: - Session Control

    /// Start an immersive isochronic session
    public func startSession(preset: IsochronicPreset) {
        currentPreset = preset
        visualMode = preset.visualMode
        state.currentFrequency = preset.targetFrequency
        state.isActive = true
        state.currentPhase = .rampUp
        state.elapsedTime = 0

        // Reset analytics
        analytics = SessionAnalytics()

        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            log.audio("Audio session configuration failed: \(error)", level: .error)
        }

        // Start audio engine
        do {
            try audioEngine?.start()
        } catch {
            log.audio("Audio engine start failed: \(error)", level: .error)
        }

        // Start timers
        startTimers()
    }

    /// Stop the current session
    public func stopSession() {
        state.isActive = false
        state.currentPhase = .complete

        audioEngine?.stop()
        stopTimers()

        // Finalize analytics
        analytics.totalDuration = state.elapsedTime
        if !analytics.coherenceHistory.isEmpty {
            analytics.averageCoherence = analytics.coherenceHistory.reduce(0, +) / Float(analytics.coherenceHistory.count)
        }
    }

    /// Pause the session
    public func pauseSession() {
        state.isActive = false
        audioEngine?.pause()
        stopTimers()
    }

    /// Resume a paused session
    public func resumeSession() {
        state.isActive = true
        do {
            try audioEngine?.start()
        } catch {
            log.error("Failed to resume audio engine in immersive session: \(error)")
        }
        startTimers()
    }

    // MARK: - Timer Management

    private func startTimers() {
        // Session timer (1 Hz)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSession()
            }
        }

        // Visual/Bio update timer (60 Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateVisuals()
            }
        }
    }

    private func stopTimers() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Update Loop

    private func updateSession() {
        guard state.isActive else { return }

        state.elapsedTime += 1

        // Update phase based on elapsed time
        let duration = currentPreset.suggestedDuration
        let progress = state.elapsedTime / duration

        if progress < 0.1 {
            state.currentPhase = .rampUp
        } else if progress < 0.3 {
            state.currentPhase = .entrainment
        } else if progress < 0.7 {
            state.currentPhase = .peak
        } else if progress < 0.9 {
            state.currentPhase = .rampDown
        } else {
            state.currentPhase = .integration
        }

        // Adaptive frequency based on coherence
        if bioModulation.adaptiveFrequency {
            let coherenceDelta = bioInput.hrvCoherence - bioModulation.targetCoherence
            let frequencyAdjustment = coherenceDelta * 2.0  // ±2 Hz adjustment
            state.currentFrequency = currentPreset.targetFrequency + frequencyAdjustment
            state.currentFrequency = max(1.0, min(45.0, state.currentFrequency))
        }

        // Update analytics
        state.currentCoherence = bioInput.hrvCoherence
        analytics.coherenceHistory.append(bioInput.hrvCoherence)
        if bioInput.hrvCoherence > analytics.peakCoherence {
            analytics.peakCoherence = bioInput.hrvCoherence
        }

        // Check for entrainment achievement
        if bioInput.hrvCoherence > 0.7 {
            analytics.entrainmentAchieved = true
            analytics.entrainmentDuration += 1
        }

        // Calculate entrainment score
        let coherenceScore = bioInput.hrvCoherence * 40
        let durationScore = min(Float(state.elapsedTime / 60), 30)  // Max 30 points for duration
        let stabilityScore = calculateStabilityScore() * 30
        state.entrainmentScore = coherenceScore + durationScore + stabilityScore
    }

    private func updateVisuals() {
        guard state.isActive else { return }

        // Bio-reactive visual modulation
        let coherenceInfluence = bioModulation.coherenceToVisualIntensity
        let breathInfluence = bioModulation.breathingToVisualScale

        // Update visual parameters based on bio input
        visualParameters.pulseIntensity = 0.3 + (bioInput.hrvCoherence * coherenceInfluence * 0.7)
        visualParameters.scale = 0.8 + (bioInput.breathPhase * breathInfluence * 0.4)
        visualParameters.brightness = 0.5 + (bioInput.hrvCoherence * 0.4)

        // Rotation synced to breathing
        visualParameters.rotationSpeed = 0.05 + (bioInput.breathingRate / 60.0) * 0.1

        // Color shifts based on coherence
        if bioInput.hrvCoherence > 0.7 {
            // High coherence: golden/white tones
            visualParameters.hue = 0.12  // Gold
            visualParameters.saturation = 0.6
        } else if bioInput.hrvCoherence > 0.4 {
            // Medium coherence: blue/cyan
            visualParameters.hue = 0.55
            visualParameters.saturation = 0.7
        } else {
            // Low coherence: purple/violet
            visualParameters.hue = 0.75
            visualParameters.saturation = 0.8
        }

        state.visualIntensity = visualParameters.pulseIntensity
    }

    private func calculateStabilityScore() -> Float {
        guard analytics.coherenceHistory.count > 10 else { return 0.5 }

        let recent = Array(analytics.coherenceHistory.suffix(10))
        let mean = recent.reduce(0, +) / Float(recent.count)
        let variance = recent.map { pow($0 - mean, 2) }.reduce(0, +) / Float(recent.count)
        let stability = 1.0 - min(sqrt(variance) * 5, 1.0)

        return stability
    }

    // MARK: - Bio Input Updates

    /// Update bio input from external source (HealthKit, sensors)
    public func updateBioInput(heartRate: Float? = nil, hrvCoherence: Float? = nil,
                               breathingRate: Float? = nil, breathPhase: Float? = nil) {
        if let hr = heartRate { bioInput.heartRate = hr }
        if let hrv = hrvCoherence { bioInput.hrvCoherence = hrv }
        if let br = breathingRate { bioInput.breathingRate = br }
        if let bp = breathPhase { bioInput.breathPhase = bp }
    }

    // MARK: - Volume Control

    /// Set audio volume (0-1)
    public func setVolume(_ volume: Float) {
        state.audioLevel = max(0, min(1, volume))
    }

    // MARK: - Cleanup

    deinit {
        // stopSession() is @MainActor-isolated, cannot call from deinit
        // Audio engine and timers will stop when references are released
    }
}

// MARK: - SwiftUI View

/// Main view for immersive isochronic sessions
public struct ImmersiveIsochronicView: View {
    @StateObject private var session = ImmersiveIsochronicSession()
    @State private var selectedPreset: IsochronicPreset = .relaxationPortal
    @State private var showingSettings = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background visualization
            IsochronicVisualizationView(
                mode: session.visualMode,
                parameters: session.visualParameters,
                isActive: session.state.isActive
            )
            .ignoresSafeArea()

            // Control overlay
            VStack {
                // Header
                HStack {
                    Text(session.state.isActive ? session.currentPreset.rawValue : "Immersive Isochronic")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showingSettings.toggle() }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))

                Spacer()

                // Session info
                if session.state.isActive {
                    sessionInfoView
                }

                Spacer()

                // Controls
                controlsView
                    .padding()
                    .background(Color.black.opacity(0.5))
            }
        }
        .sheet(isPresented: $showingSettings) {
            settingsView
        }
    }

    private var sessionInfoView: some View {
        VStack(spacing: 8) {
            // Phase indicator
            Text(session.state.currentPhase.rawValue)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            // Timer
            Text(formatTime(session.state.elapsedTime))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(.white)

            // Frequency
            Text("\(session.state.currentFrequency, specifier: "%.1f") Hz")
                .font(.title2)
                .foregroundColor(.cyan)

            // Entrainment score
            HStack {
                Text("Entrainment")
                    .foregroundColor(.white.opacity(0.7))
                ProgressView(value: Double(session.state.entrainmentScore), total: 100)
                    .tint(.green)
                    .frame(width: 100)
                Text("\(Int(session.state.entrainmentScore))%")
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }

    private var controlsView: some View {
        VStack(spacing: 16) {
            if !session.state.isActive {
                // Preset picker
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(IsochronicPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)

                // Preset description
                Text(selectedPreset.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Play/Stop button
            Button(action: {
                if session.state.isActive {
                    session.stopSession()
                } else {
                    session.startSession(preset: selectedPreset)
                }
            }) {
                HStack {
                    Image(systemName: session.state.isActive ? "stop.fill" : "play.fill")
                    Text(session.state.isActive ? "End Session" : "Begin Journey")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(session.state.isActive ? Color.red : Color.blue)
                .cornerRadius(12)
            }

            // Volume slider
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.white)
                Slider(value: Binding(
                    get: { Double(session.state.audioLevel) },
                    set: { session.setVolume(Float($0)) }
                ), in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.white)
            }
        }
    }

    private var settingsView: some View {
        NavigationView {
            Form {
                Section("Audio Mode") {
                    Picker("Mode", selection: $session.audioMode) {
                        ForEach(IsochronicAudioMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    if session.audioMode == .binaural && !session.isHeadphonesConnected {
                        Text("⚠️ Headphones required for binaural beats")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Section("Bio Modulation") {
                    Toggle("Adaptive Frequency", isOn: $session.bioModulation.adaptiveFrequency)

                    VStack(alignment: .leading) {
                        Text("Coherence → Visual: \(Int(session.bioModulation.coherenceToVisualIntensity * 100))%")
                        Slider(value: $session.bioModulation.coherenceToVisualIntensity, in: 0...1)
                    }

                    VStack(alignment: .leading) {
                        Text("Breathing → Scale: \(Int(session.bioModulation.breathingToVisualScale * 100))%")
                        Slider(value: $session.bioModulation.breathingToVisualScale, in: 0...1)
                    }
                }

                Section("Visual Mode") {
                    Picker("Mode", selection: $session.visualMode) {
                        ForEach(IsochronicVisualMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Health Disclaimer") {
                    Text("This feature is for relaxation and creative purposes only. It is NOT a medical device and makes no health claims. If you have epilepsy, seizure disorders, or are sensitive to flashing lights, consult a healthcare professional before use.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Visualization View

/// Visual rendering for isochronic sessions
struct IsochronicVisualizationView: View {
    let mode: IsochronicVisualMode
    let parameters: ImmersiveIsochronicSession.VisualParameters
    let isActive: Bool

    @State private var animationPhase: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(hue: Double(parameters.hue), saturation: 0.3, brightness: 0.1))
                )

                guard isActive else { return }

                // Draw based on mode
                switch mode {
                case .breathingMandala:
                    drawMandala(context: context, center: center, size: size, time: time)
                case .flowTunnel:
                    drawTunnel(context: context, center: center, size: size, time: time)
                case .coherenceField:
                    drawCoherenceField(context: context, center: center, size: size, time: time)
                case .gentleWaves:
                    drawWaves(context: context, size: size, time: time)
                case .energyParticles:
                    drawParticles(context: context, center: center, size: size, time: time)
                case .quantumField:
                    drawQuantumField(context: context, center: center, size: size, time: time)
                case .sacredPatterns:
                    drawSacredGeometry(context: context, center: center, size: size, time: time)
                default:
                    drawMandala(context: context, center: center, size: size, time: time)
                }
            }
        }
    }

    private func drawMandala(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        let scale = CGFloat(parameters.scale)
        let baseRadius = min(size.width, size.height) * 0.3 * scale
        let pulse = CGFloat(parameters.pulseIntensity) * sin(time * 2) * 0.2

        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 + time * Double(parameters.rotationSpeed)
            let radius = baseRadius * (1 + pulse)

            var path = Path()
            path.addArc(
                center: center,
                radius: radius * CGFloat(1 - Double(i) * 0.1),
                startAngle: .radians(angle),
                endAngle: .radians(angle + .pi * 2),
                clockwise: false
            )

            let opacity = Double(parameters.brightness) * (1 - Double(i) * 0.1)
            context.stroke(
                path,
                with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: opacity)),
                lineWidth: 2
            )
        }
    }

    private func drawTunnel(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        let depth = 20
        for i in 0..<depth {
            let progress = Double(i) / Double(depth)
            let z = 1 - progress + fmod(time * 0.3, 1)
            let radius = min(size.width, size.height) * 0.4 / CGFloat(z)

            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            let opacity = (1 - progress) * Double(parameters.brightness)
            context.stroke(
                path,
                with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: opacity)),
                lineWidth: 1
            )
        }
    }

    private func drawCoherenceField(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        let gridSize = 20
        let cellWidth = size.width / CGFloat(gridSize)
        let cellHeight = size.height / CGFloat(gridSize)

        for x in 0..<gridSize {
            for y in 0..<gridSize {
                let dx = CGFloat(x) - CGFloat(gridSize) / 2
                let dy = CGFloat(y) - CGFloat(gridSize) / 2
                let distance = sqrt(dx * dx + dy * dy)
                let wave = sin(distance * 0.5 - time * 2) * CGFloat(parameters.pulseIntensity)

                let rect = CGRect(
                    x: CGFloat(x) * cellWidth,
                    y: CGFloat(y) * cellHeight,
                    width: cellWidth * 0.8,
                    height: cellHeight * 0.8
                )

                let brightness = Double(parameters.brightness) * (0.5 + wave * 0.5)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: max(0, brightness)))
                )
            }
        }
    }

    private func drawWaves(context: GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<5 {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))

            for x in stride(from: 0, to: size.width, by: 2) {
                let y = size.height / 2 +
                    sin(x * 0.02 + time * Double(i + 1) * 0.5) * 50 * CGFloat(parameters.pulseIntensity) +
                    CGFloat(i - 2) * 30
                path.addLine(to: CGPoint(x: x, y: y))
            }

            let opacity = Double(parameters.brightness) * (1 - Double(i) * 0.15)
            context.stroke(
                path,
                with: .color(Color(hue: Double(parameters.hue) + Double(i) * 0.05, saturation: Double(parameters.saturation), brightness: opacity)),
                lineWidth: 2
            )
        }
    }

    private func drawParticles(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        let count = parameters.particleCount
        for i in 0..<count {
            let seed = Double(i) * 1.618
            let angle = seed * .pi * 2 + time * Double(parameters.rotationSpeed)
            let radius = (seed.truncatingRemainder(dividingBy: 1)) * Double(min(size.width, size.height)) * 0.4

            let x = center.x + CGFloat(cos(angle) * radius)
            let y = center.y + CGFloat(sin(angle) * radius)
            let particleSize = CGFloat(2 + sin(time + seed) * 2) * CGFloat(parameters.scale)

            context.fill(
                Path(ellipseIn: CGRect(x: x - particleSize/2, y: y - particleSize/2, width: particleSize, height: particleSize)),
                with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: Double(parameters.brightness)))
            )
        }
    }

    private func drawQuantumField(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        // Interference pattern
        let resolution = 40
        let cellWidth = size.width / CGFloat(resolution)
        let cellHeight = size.height / CGFloat(resolution)

        for x in 0..<resolution {
            for y in 0..<resolution {
                let px = CGFloat(x) * cellWidth
                let py = CGFloat(y) * cellHeight

                // Two wave sources
                let d1 = sqrt(pow(px - size.width * 0.3, 2) + pow(py - size.height * 0.5, 2))
                let d2 = sqrt(pow(px - size.width * 0.7, 2) + pow(py - size.height * 0.5, 2))

                let wave1 = sin(d1 * 0.05 - time * 3)
                let wave2 = sin(d2 * 0.05 - time * 3)
                let interference = (wave1 + wave2) / 2

                let brightness = Double(parameters.brightness) * (0.5 + interference * 0.5 * Double(parameters.pulseIntensity))

                context.fill(
                    Path(CGRect(x: px, y: py, width: cellWidth, height: cellHeight)),
                    with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: max(0, brightness)))
                )
            }
        }
    }

    private func drawSacredGeometry(context: GraphicsContext, center: CGPoint, size: CGSize, time: Double) {
        let radius = min(size.width, size.height) * 0.35 * CGFloat(parameters.scale)

        // Flower of Life pattern
        let circles = 7
        let innerRadius = radius / 3

        // Center circle
        var centerPath = Path()
        centerPath.addArc(center: center, radius: innerRadius, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)
        context.stroke(centerPath, with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: Double(parameters.brightness))), lineWidth: 1)

        // Surrounding circles
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + time * Double(parameters.rotationSpeed)
            let cx = center.x + CGFloat(cos(angle)) * innerRadius
            let cy = center.y + CGFloat(sin(angle)) * innerRadius

            var path = Path()
            path.addArc(center: CGPoint(x: cx, y: cy), radius: innerRadius, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)

            let hueShift = Double(i) * 0.05
            context.stroke(path, with: .color(Color(hue: Double(parameters.hue) + hueShift, saturation: Double(parameters.saturation), brightness: Double(parameters.brightness))), lineWidth: 1)
        }

        // Outer ring
        var outerPath = Path()
        outerPath.addArc(center: center, radius: radius, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)
        context.stroke(outerPath, with: .color(Color(hue: Double(parameters.hue), saturation: Double(parameters.saturation), brightness: Double(parameters.brightness) * 0.5)), lineWidth: 1)
    }
}

// MARK: - Preview

#if DEBUG
struct ImmersiveIsochronicView_Previews: PreviewProvider {
    static var previews: some View {
        ImmersiveIsochronicView()
    }
}
#endif
