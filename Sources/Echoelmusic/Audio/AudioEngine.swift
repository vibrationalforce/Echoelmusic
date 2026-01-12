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
class AudioEngine: ObservableObject {

    // MARK: - Published Properties

    /// Whether the audio engine is currently running
    @Published var isRunning: Bool = false

    /// Whether isochronic entrainment is enabled
    @Published var isochronicEnabled: Bool = false

    /// Whether spatial audio is enabled
    @Published var spatialAudioEnabled: Bool = false

    /// Current entrainment preset
    @Published var currentEntrainmentPreset: ImmersiveIsochronicEngine.EntrainmentPreset = .relaxedFocus

    /// Isochronic volume (0.0 - 1.0)
    @Published var isochronicVolume: Float = 0.5


    // MARK: - Audio Components

    /// Microphone manager for voice/breath input
    let microphoneManager: MicrophoneManager

    /// Immersive isochronic engine for brainwave entrainment with rich sound design
    /// HINWEIS: Subjektive Entspannung, keine medizinischen Heilungseffekte belegt
    private let isochronicEngine = ImmersiveIsochronicEngine()

    /// Spatial audio engine for 3D audio
    private var spatialAudioEngine: SpatialAudioEngine?

    /// Bio-parameter mapper (HRV/HR → Audio parameters)
    private let bioParameterMapper = BioParameterMapper()

    /// HealthKit manager for HRV-based adaptations
    private var healthKitManager: HealthKitManager?

    /// Head tracking manager
    private var headTrackingManager: HeadTrackingManager?

    /// Device capabilities
    private var deviceCapabilities: DeviceCapabilities?

    /// Node graph for effects processing
    private var nodeGraph: NodeGraph?


    // MARK: - Private Properties

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization

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

        // Configure default isochronic entrainment settings
        // Uses rich soundscapes instead of boring sine waves
        isochronicEngine.configure(preset: .relaxedFocus, soundscape: .warmPad)

        // Initialize device capabilities
        deviceCapabilities = DeviceCapabilities()

        // Initialize head tracking if available
        headTrackingManager = HeadTrackingManager()

        // Initialize spatial audio if available (iOS 15+)
        if let headTracking = headTrackingManager,
           let capabilities = deviceCapabilities,
           capabilities.canUseSpatialAudioEngine {
            spatialAudioEngine = SpatialAudioEngine(
                headTrackingManager: headTracking,
                deviceCapabilities: capabilities
            )
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

        // Start isochronic entrainment if enabled
        if isochronicEnabled {
            isochronicEngine.start()
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

        // Stop isochronic entrainment
        isochronicEngine.stop()

        // Stop spatial audio
        spatialAudioEngine?.stop()

        // Stop bio-parameter mapping
        stopBioParameterMapping()

        isRunning = false
        log.audio("🎵 AudioEngine stopped")
    }

    /// Toggle isochronic entrainment on/off
    func toggleIsochronicEntrainment() {
        isochronicEnabled.toggle()

        if isochronicEnabled {
            isochronicEngine.start()
            log.audio("Isochronic entrainment enabled")
        } else {
            isochronicEngine.stop()
            log.audio("Isochronic entrainment disabled")
        }
    }

    /// Set entrainment preset for isochronic tones
    /// - Parameter preset: Target entrainment preset (deepRest, meditation, relaxedFocus, focus, activeThinking, peakFlow)
    func setEntrainmentPreset(_ preset: ImmersiveIsochronicEngine.EntrainmentPreset) {
        currentEntrainmentPreset = preset
        isochronicEngine.configure(preset: preset)
        log.audio("Entrainment preset set to: \(preset.displayName)")
    }

    /// Set isochronic volume
    /// - Parameter volume: Volume (0.0 - 1.0)
    func setIsochronicVolume(_ volume: Float) {
        isochronicVolume = volume
        isochronicEngine.volume = volume
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

    /// Connect to HealthKit manager for HRV-based adaptations
    /// - Parameter healthKitManager: HealthKit manager instance
    func connectHealthKit(_ healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager

        // Subscribe to HRV coherence changes
        healthKitManager.$hrvCoherence
            .sink { [weak self] coherence in
                self?.adaptToBiofeedback(coherence: coherence)
            }
            .store(in: &cancellables)
    }


    // MARK: - Private Methods

    /// Adapt isochronic rhythm based on HRV coherence
    /// - Parameter coherence: HRV coherence score (0-100)
    private func adaptToBiofeedback(coherence: Double) {
        guard isochronicEnabled else { return }

        // Use HRV to modulate isochronic rhythm
        isochronicEngine.modulateFromCoherence(coherence)

        // Optional: Adjust volume based on coherence
        // Higher coherence = can handle higher volume
        let adaptiveVolume = Float(0.3 + (coherence / 100.0) * 0.4)  // 0.3-0.7 range
        isochronicVolume = adaptiveVolume
        isochronicEngine.volume = adaptiveVolume
    }


    /// Start bio-parameter mapping (HRV/HR → Audio)
    private func startBioParameterMapping() {
        guard let healthKit = healthKitManager else {
            log.audio("⚠️  Bio-parameter mapping: HealthKit not connected", level: .warning)
            return
        }

        // Update bio-parameters every 100ms
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBioParameters()
            }
            .store(in: &cancellables)

        log.audio("🎛️  Bio-parameter mapping started")
    }

    /// Stop bio-parameter mapping
    private func stopBioParameterMapping() {
        // Cancellables will be cleared when engine stops
        log.audio("🎛️  Bio-parameter mapping stopped")
    }

    /// Update bio-parameters from current biometric data
    private func updateBioParameters() {
        guard let healthKit = healthKitManager else { return }

        // Get current biometric data
        let hrvCoherence = healthKit.hrvCoherence
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

            // Apply spatial positioning based on HRV
            let pos = bioParameterMapper.spatialPosition
            spatial.positionSource(x: pos.x, y: pos.y, z: pos.z)
        }

        // Apply amplitude to isochronic engine
        if isochronicEnabled {
            isochronicEngine.volume = bioParameterMapper.amplitude
        }
    }


    // MARK: - Utility Methods

    /// Get human-readable description of current state
    var stateDescription: String {
        if !isRunning {
            return "Audio engine stopped"
        }

        var description = "Microphone: Active"

        if isochronicEnabled {
            description += "\nIsochronic Entrainment: \(currentEntrainmentPreset.displayName) (\(currentEntrainmentPreset.centerFrequency) Hz)"
        } else {
            description += "\nIsochronic Entrainment: Off"
        }

        if spatialAudioEnabled {
            description += "\nSpatial Audio: Active"
            if let spatial = spatialAudioEngine {
                description += " (\(spatial.spatialMode.rawValue))"
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
}
