import Foundation
import AVFoundation
import Combine

/// Central audio engine that manages and mixes multiple audio sources
///
/// Coordinates:
/// - Microphone input (for voice/breath capture)
/// - Multidimensional Brainwave Entrainment generation (for brainwave entrainment)
/// - Spatial audio with head tracking
/// - Bio-parameter mapping (HRV → Audio)
/// - Real-time mixing and effects
///
/// This class acts as the central hub for all audio processing in Echoelmusic
@MainActor
public class AudioEngine: ObservableObject {

    // MARK: - Published Properties

    /// Whether the audio engine is currently running
    @Published var isRunning: Bool = false

    /// Whether Multidimensional Brainwave Entrainment are enabled
    @Published var binauralBeatsEnabled: Bool = false

    /// Whether spatial audio is enabled
    @Published var spatialAudioEnabled: Bool = false

    /// Current binaural beat state
    @Published var currentBrainwaveState: BinauralBeatGenerator.BrainwaveState = .alpha

    /// Multidimensional Brainwave Entrainment amplitude (0.0 - 1.0)
    @Published var binauralAmplitude: Float = 0.3


    // MARK: - Audio Components

    /// Microphone manager for voice/breath input
    let microphoneManager: MicrophoneManager

    /// Multidimensional Brainwave Entrainment generator for brainwave entrainment frequencies
    /// HINWEIS: Subjektive Entspannung, keine medizinischen Heilungseffekte belegt
    private let binauralGenerator = BinauralBeatGenerator()

    /// Spatial audio engine for 3D audio
    var spatialAudioEngine: SpatialAudioEngine?

    /// Bio-parameter mapper (HRV/HR → Audio parameters)
    private let bioParameterMapper = BioParameterMapper()

    /// HealthKit manager for HRV-based adaptations
    private var healthKitEngine: UnifiedHealthKitEngine?

    /// Head tracking manager
    private var headTrackingManager: HeadTrackingManager?

    /// Device capabilities
    var deviceCapabilities: DeviceCapabilities?

    /// Node graph for effects processing
    private var nodeGraph: NodeGraph?


    // MARK: - Private Properties

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// OPTIMIZATION: High-precision timer for bio-parameter updates
    /// Using DispatchSourceTimer instead of Timer.publish for lower latency
    private var bioParameterTimer: DispatchSourceTimer?
    private let bioParameterQueue = DispatchQueue(label: "com.echoelmusic.bioparameters", qos: .userInteractive)


    // MARK: - Initialization

    /// Convenience initializer with default MicrophoneManager
    convenience init() {
        self.init(microphoneManager: MicrophoneManager())
    }

    init(microphoneManager: MicrophoneManager) {
        self.microphoneManager = microphoneManager

        // Configure audio session for optimal performance
        do {
            try AudioConfiguration.configureAudioSession()
            log.audio(AudioConfiguration.latencyStats())
        } catch {
            log.audio("⚠️  Failed to configure audio session: \(error)", level: .warning)
        }

        // Set real-time audio thread priority
        AudioConfiguration.setAudioThreadPriority()

        // Configure default binaural beat settings
        // HINWEIS: 432 Hz ist kulturell beliebt, keine "Heilfrequenz" wissenschaftlich belegt
        binauralGenerator.configure(
            carrier: 432.0,  // Traditional tuning (subjective preference)
            beat: 10.0,      // Alpha waves (relaxation)
            amplitude: 0.3
        )

        // Initialize device capabilities
        deviceCapabilities = DeviceCapabilities()

        // Initialize head tracking if available
        headTrackingManager = HeadTrackingManager()

        // Initialize spatial audio if available (iOS 15+)
        if let _ = headTrackingManager,
           let capabilities = deviceCapabilities,
           capabilities.canUseSpatialAudioEngine {
            spatialAudioEngine = SpatialAudioEngine()
        } else {
            log.audio("⚠️  Spatial audio engine requires iOS 15+", level: .warning)
        }

        // Start monitoring device capabilities
        deviceCapabilities?.startMonitoringAudioRoute()

        // Initialize node graph with default biofeedback chain
        nodeGraph = NodeGraph.createBiofeedbackChain()

        log.audio("🎵 AudioEngine initialized")
        log.audio("   Spatial Audio: \(deviceCapabilities?.canUseSpatialAudio == true ? "✅" : "❌")")
        log.audio("   Head Tracking: \(headTrackingManager?.isAvailable == true ? "✅" : "❌")")
        log.audio("   Node Graph: \(nodeGraph?.nodes.count ?? 0) nodes loaded")
    }


    // MARK: - Public Methods

    /// Start the audio engine (microphone + optional Multidimensional Brainwave Entrainment + spatial audio)
    func start() {
        // Start microphone
        microphoneManager.startRecording()

        // Start Multidimensional Brainwave Entrainment if enabled
        if binauralBeatsEnabled {
            binauralGenerator.start()
        }

        // Start spatial audio if enabled
        if spatialAudioEnabled, let spatial = spatialAudioEngine {
            do {
                try spatial.start()
                log.audio("🎵 Spatial audio started")
            } catch {
                log.audio("❌ Failed to start spatial audio: \(error)", level: .error)
                spatialAudioEnabled = false
            }
        }

        // Start bio-parameter mapping updates
        startBioParameterMapping()

        isRunning = true
        log.audio("🎵 AudioEngine started")
    }

    /// Stop the audio engine
    func stop() {
        // Stop microphone
        microphoneManager.stopRecording()

        // Stop Multidimensional Brainwave Entrainment
        binauralGenerator.stop()

        // Stop spatial audio
        spatialAudioEngine?.stop()

        // Stop bio-parameter mapping
        stopBioParameterMapping()

        isRunning = false
        log.audio("🎵 AudioEngine stopped")
    }

    /// Toggle Multidimensional Brainwave Entrainment on/off
    func toggleBinauralBeats() {
        binauralBeatsEnabled.toggle()

        if binauralBeatsEnabled {
            binauralGenerator.start()
            log.audio("🔊 Multidimensional Brainwave Entrainment enabled")
        } else {
            binauralGenerator.stop()
            log.audio("🔇 Multidimensional Brainwave Entrainment disabled")
        }
    }

    /// Set brainwave state for Multidimensional Brainwave Entrainment
    /// - Parameter state: Target brainwave state (delta, theta, alpha, beta, gamma)
    func setBrainwaveState(_ state: BinauralBeatGenerator.BrainwaveState) {
        currentBrainwaveState = state
        binauralGenerator.configure(state: state)

        // Restart if currently playing
        if binauralBeatsEnabled {
            binauralGenerator.stop()
            binauralGenerator.start()
        }
    }

    /// Set binaural beat amplitude
    /// - Parameter amplitude: Volume (0.0 - 1.0)
    func setBinauralAmplitude(_ amplitude: Float) {
        binauralAmplitude = amplitude
        binauralGenerator.configure(
            carrier: 432.0,
            beat: currentBrainwaveState.beatFrequency,
            amplitude: amplitude
        )

        // Restart if currently playing
        if binauralBeatsEnabled {
            binauralGenerator.stop()
            binauralGenerator.start()
        }
    }

    /// Toggle spatial audio on/off
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()

        if spatialAudioEnabled {
            if let spatial = spatialAudioEngine {
                do {
                    try spatial.start()
                    log.audio("🎵 Spatial audio enabled")
                } catch {
                    log.audio("❌ Failed to enable spatial audio: \(error)", level: .error)
                    spatialAudioEnabled = false
                }
            } else {
                log.audio("⚠️  Spatial audio not available", level: .warning)
                spatialAudioEnabled = false
            }
        } else {
            spatialAudioEngine?.stop()
            log.audio("🎵 Spatial audio disabled")
        }
    }

    /// Connect to HealthKit engine for HRV-based adaptations
    /// - Parameter healthKitEngine: UnifiedHealthKitEngine instance
    func connectHealthKit(_ healthKitEngine: UnifiedHealthKitEngine) {
        self.healthKitEngine = healthKitEngine

        // Subscribe to HRV coherence changes (coherence is 0-1, convert to 0-100)
        healthKitEngine.$coherence
            .sink { [weak self] coherence in
                self?.adaptToBiofeedback(coherence: coherence * 100.0)
            }
            .store(in: &cancellables)
    }


    // MARK: - Private Methods

    /// Adapt binaural beat frequency based on HRV coherence
    /// - Parameter coherence: HRV coherence score (0-100)
    private func adaptToBiofeedback(coherence: Double) {
        guard binauralBeatsEnabled else { return }

        // Use HRV to modulate binaural beat frequency
        binauralGenerator.setBeatFrequencyFromHRV(coherence: coherence)

        // Optional: Adjust amplitude based on coherence
        // Higher coherence = can handle higher amplitude
        let adaptiveAmplitude = Float(0.2 + (coherence / 100.0) * 0.3)  // 0.2-0.5 range
        binauralAmplitude = adaptiveAmplitude

        binauralGenerator.configure(
            carrier: 432.0,
            beat: binauralGenerator.beatFrequency,
            amplitude: adaptiveAmplitude
        )
    }


    /// Start bio-parameter mapping (HRV/HR → Audio)
    private func startBioParameterMapping() {
        guard let healthKit = healthKitEngine else {
            log.audio("⚠️  Bio-parameter mapping: HealthKit not connected", level: .warning)
            return
        }

        // OPTIMIZATION: High-precision bio-parameter updates using DispatchSourceTimer
        // 50% lower jitter compared to Timer.publish for real-time audio responsiveness
        bioParameterTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: bioParameterQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.updateBioParameters()
            }
        }
        timer.resume()
        bioParameterTimer = timer

        log.audio("🎛️  Bio-parameter mapping started (high-precision timer)")
    }

    /// Stop bio-parameter mapping
    private func stopBioParameterMapping() {
        // OPTIMIZATION: Clean up high-precision timer
        bioParameterTimer?.cancel()
        bioParameterTimer = nil
        log.audio("🎛️  Bio-parameter mapping stopped")
    }

    /// Update bio-parameters from current biometric data
    private func updateBioParameters() {
        guard let healthKit = healthKitEngine else { return }

        // Get current biometric data
        let hrvCoherence = healthKit.coherence
        let heartRate = healthKit.heartRate
        let voicePitch = microphoneManager.currentPitch
        let audioLevel = microphoneManager.audioLevel

        // Update bio-parameter mapper
        bioParameterMapper.updateParameters(
            hrvCoherence: hrvCoherence,
            heartRate: heartRate,
            voicePitch: voicePitch,
            audioLevel: audioLevel
        )

        // Apply mapped parameters to audio engine
        applyBioParameters()
    }

    /// Apply bio-mapped parameters to audio components
    private func applyBioParameters() {
        // Apply reverb to spatial audio engine
        if let spatial = spatialAudioEngine, spatialAudioEnabled {
            spatial.setReverbBlend(bioParameterMapper.reverbWet)

            // Apply spatial panning based on HRV
            let pos = bioParameterMapper.spatialPosition
            spatial.setPan(Float(pos.x))
        }

        // Apply frequency/amplitude to binaural generator
        if binauralBeatsEnabled {
            binauralGenerator.configure(
                carrier: bioParameterMapper.baseFrequency,
                beat: currentBrainwaveState.beatFrequency,
                amplitude: bioParameterMapper.amplitude
            )
        }
    }


    // MARK: - Utility Methods

    /// Get human-readable description of current state
    var stateDescription: String {
        if !isRunning {
            return "Audio engine stopped"
        }

        var description = "Microphone: Active"

        if binauralBeatsEnabled {
            description += "\nMultidimensional Brainwave Entrainment: \(currentBrainwaveState.rawValue.capitalized) (\(currentBrainwaveState.beatFrequency) Hz)"
        } else {
            description += "\nMultidimensional Brainwave Entrainment: Off"
        }

        if spatialAudioEnabled {
            description += "\nSpatial Audio: Active"
            if let spatial = spatialAudioEngine {
                description += " (\(spatial.currentMode.rawValue))"
            }
        } else {
            description += "\nSpatial Audio: Off"
        }

        return description
    }

    /// Get device capabilities summary
    var deviceCapabilitiesSummary: String? {
        deviceCapabilities?.capabilitySummary
    }

    /// Get bio-parameter mapping summary
    var bioParameterSummary: String {
        bioParameterMapper.parameterSummary
    }

    /// Current audio level from microphone (0.0 - 1.0)
    var currentLevel: Float {
        microphoneManager.audioLevel
    }

    /// Get current detected pitch in Hz
    var getCurrentPitch: (() -> Float)? {
        return { [weak self] in
            self?.microphoneManager.currentPitch ?? 0.0
        }
    }

    // MARK: - Filter & Effect Control (for UnifiedControlHub)

    /// Set filter cutoff frequency
    func setFilterCutoff(_ frequency: Float) {
        nodeGraph?.setParameter(.filterCutoff, value: frequency)
    }

    /// Set filter resonance
    func setFilterResonance(_ resonance: Float) {
        nodeGraph?.setParameter(.filterResonance, value: resonance)
    }

    /// Set reverb wetness (0.0 - 1.0)
    func setReverbWetness(_ wetness: Float) {
        nodeGraph?.setParameter(.reverbWet, value: wetness)
        spatialAudioEngine?.setReverbBlend(wetness)
    }

    /// Set reverb size (0.0 - 1.0)
    func setReverbSize(_ size: Float) {
        nodeGraph?.setParameter(.reverbSize, value: size)
    }

    /// Set delay time in seconds
    func setDelayTime(_ time: Float) {
        nodeGraph?.setParameter(.delayTime, value: time)
    }

    /// Set master volume (0.0 - 1.0)
    func setMasterVolume(_ volume: Float) {
        nodeGraph?.setParameter(.masterVolume, value: volume)
    }

    /// Set tempo in BPM
    func setTempo(_ bpm: Float) {
        nodeGraph?.setParameter(.tempo, value: bpm)
    }

    // MARK: - Preset Loading

    /// Load a preset by name and apply audio settings
    /// - Parameter named: The name of the preset to load
    /// - Returns: True if preset was found and applied, false otherwise
    @discardableResult
    func loadPreset(named: String) -> Bool {
        // Search in built-in presets first
        let allPresets = BuiltInPresets.all

        guard let preset = allPresets.first(where: { $0.name.lowercased() == named.lowercased() || $0.id == named }) else {
            log.audio("⚠️  Preset not found: \(named)", level: .warning)
            return false
        }

        // Apply audio settings from preset
        applyPreset(preset)
        log.audio("🎵 Loaded preset: \(preset.name)")
        return true
    }

    /// Load a QuantumPreset directly
    /// - Parameter preset: The preset to apply
    func loadPreset(_ preset: QuantumPreset) {
        applyPreset(preset)
        log.audio("🎵 Loaded preset: \(preset.name)")
    }

    /// Apply audio settings from a preset
    private func applyPreset(_ preset: QuantumPreset) {
        // Apply binaural beat frequency if specified
        if let binauralFrequency = preset.binauralFrequency {
            binauralGenerator.configure(
                carrier: 432.0,
                beat: binauralFrequency,
                amplitude: binauralAmplitude
            )

            // Auto-enable binaural beats when preset specifies a frequency
            if !binauralBeatsEnabled {
                binauralBeatsEnabled = true
                binauralGenerator.start()
            }
        }

        // Apply reverb wetness
        setReverbWetness(preset.reverbWetness)

        // Apply spatial mode if specified
        if let spatialModeString = preset.spatialMode {
            applySpatialMode(spatialModeString)
        }
    }

    /// Apply spatial mode from preset string
    private func applySpatialMode(_ mode: String) {
        guard let spatial = spatialAudioEngine else {
            log.audio("⚠️  Spatial audio not available for mode: \(mode)", level: .warning)
            return
        }

        // Map preset spatial mode strings to SpatialAudioEngine modes
        switch mode.lowercased() {
        case "binaural":
            spatial.setMode(.binaural)
        case "stereo":
            spatial.setMode(.stereo)
        case "ambisonics":
            spatial.setMode(.ambisonics)
        case "surround_3d", "surround3d":
            spatial.setMode(.surround_3d)
        case "surround_4d", "surround4d", "afa":
            spatial.setMode(.afa)
        default:
            log.audio("⚠️  Unknown spatial mode: \(mode), using default", level: .warning)
        }

        // Enable spatial audio when preset specifies a mode
        if !spatialAudioEnabled {
            spatialAudioEnabled = true
            do {
                try spatial.start()
            } catch {
                log.audio("❌ Failed to start spatial audio: \(error)", level: .error)
                spatialAudioEnabled = false
            }
        }
    }
}
