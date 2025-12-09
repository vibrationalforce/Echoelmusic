import Foundation
import AVFoundation
import Combine
import os.log

/// Central audio engine that manages and mixes multiple audio sources
///
/// Coordinates:
/// - Microphone input (for voice/breath capture)
/// - Spatial audio with head tracking
/// - Bio-parameter mapping (HRV → Audio/Visual modulations)
/// - Real-time mixing and effects
/// - Brainwave entrainment via audio/visual MODULATIONS (instruments + effects + lighting)
///
/// This class acts as the central hub for all audio processing in Echoelmusic
@MainActor
class AudioEngine: ObservableObject {

    // MARK: - Published Properties

    /// Whether the audio engine is currently running
    @Published var isRunning: Bool = false

    /// Whether spatial audio is enabled
    @Published var spatialAudioEnabled: Bool = false

    /// Whether modulation-based entrainment is enabled (audio/visual)
    @Published var modulationEntrainmentEnabled: Bool = false

    /// Current entrainment target frequency (Hz) - used by instruments/effects/visuals
    @Published var entrainmentFrequency: Float = 10.0  // Alpha default

    /// Error message for UI display
    @Published var errorMessage: String?


    // MARK: - Logger

    private let logger = Logger(subsystem: "com.echoelmusic", category: "AudioEngine")


    // MARK: - Audio Components

    /// Microphone manager for voice/breath input
    let microphoneManager: MicrophoneManager

    /// Spatial audio engine for 3D audio
    private(set) var spatialAudioEngine: SpatialAudioEngine?

    /// Bio-parameter mapper (HRV/HR → Audio parameters)
    private let bioParameterMapper = BioParameterMapper()

    /// HealthKit manager for HRV-based adaptations
    private var healthKitManager: HealthKitManager?

    /// Head tracking manager
    private var headTrackingManager: HeadTrackingManager?

    /// Device capabilities
    private(set) var deviceCapabilities: DeviceCapabilities?

    /// Node graph for effects processing
    private var nodeGraph: NodeGraph?


    // MARK: - Private Properties

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()


    // MARK: - Brainwave Target Frequencies

    /// Brainwave target frequencies for modulation-based entrainment
    enum BrainwaveTarget: String, CaseIterable {
        case delta = "Delta"      // 2 Hz - Deep sleep, healing
        case theta = "Theta"      // 6 Hz - Meditation, creativity
        case alpha = "Alpha"      // 10 Hz - Relaxation, learning
        case beta = "Beta"        // 20 Hz - Focus, alertness
        case gamma = "Gamma"      // 40 Hz - Peak awareness

        var frequency: Float {
            switch self {
            case .delta: return 2.0
            case .theta: return 6.0
            case .alpha: return 10.0
            case .beta: return 20.0
            case .gamma: return 40.0
            }
        }

        var description: String {
            switch self {
            case .delta: return "Deep Sleep & Healing"
            case .theta: return "Meditation & Creativity"
            case .alpha: return "Relaxation & Learning"
            case .beta: return "Focus & Alertness"
            case .gamma: return "Peak Awareness"
            }
        }
    }

    /// Current brainwave target for modulation
    @Published var currentBrainwaveTarget: BrainwaveTarget = .alpha


    // MARK: - Initialization

    init(microphoneManager: MicrophoneManager) {
        self.microphoneManager = microphoneManager

        // Configure audio session for optimal performance
        do {
            try AudioConfiguration.configureAudioSession()
            logger.info("🎵 Audio session configured - \(AudioConfiguration.latencyStats())")
        } catch {
            logger.error("⚠️ Failed to configure audio session: \(error.localizedDescription)")
            errorMessage = "Audio session configuration failed"
        }

        // Set real-time audio thread priority
        AudioConfiguration.setAudioThreadPriority()

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
            logger.warning("⚠️ Spatial audio engine requires iOS 15+")
        }

        // Start monitoring device capabilities
        deviceCapabilities?.startMonitoringAudioRoute()

        // Initialize node graph with default biofeedback chain
        nodeGraph = NodeGraph.createBiofeedbackChain()

        logger.info("🎵 AudioEngine initialized - Spatial: \(self.deviceCapabilities?.canUseSpatialAudio == true), HeadTracking: \(self.headTrackingManager?.isAvailable == true), Nodes: \(self.nodeGraph?.nodes.count ?? 0)")
    }


    // MARK: - Public Methods

    /// Start the audio engine (microphone + spatial audio + modulation entrainment)
    func start() {
        // Start microphone
        microphoneManager.startRecording()

        // Start spatial audio if enabled
        if spatialAudioEnabled, let spatial = spatialAudioEngine {
            do {
                try spatial.start()
                logger.info("🎵 Spatial audio started")
            } catch {
                logger.error("❌ Failed to start spatial audio: \(error.localizedDescription)")
                spatialAudioEnabled = false
                errorMessage = "Spatial audio failed: \(error.localizedDescription)"
            }
        }

        // Start bio-parameter mapping updates
        startBioParameterMapping()

        isRunning = true
        errorMessage = nil
        logger.info("🎵 AudioEngine started")
    }

    /// Stop the audio engine
    func stop() {
        // Stop microphone
        microphoneManager.stopRecording()

        // Stop spatial audio
        spatialAudioEngine?.stop()

        // Stop bio-parameter mapping
        stopBioParameterMapping()

        isRunning = false
        logger.info("🎵 AudioEngine stopped")
    }

    /// Toggle spatial audio on/off
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()

        if spatialAudioEnabled {
            if let spatial = spatialAudioEngine {
                do {
                    try spatial.start()
                    logger.info("🎵 Spatial audio enabled")
                    errorMessage = nil
                } catch {
                    logger.error("❌ Failed to enable spatial audio: \(error.localizedDescription)")
                    spatialAudioEnabled = false
                    errorMessage = "Spatial audio unavailable"
                }
            } else {
                logger.warning("⚠️ Spatial audio not available on this device")
                spatialAudioEnabled = false
                errorMessage = "Spatial audio requires iOS 15+"
            }
        } else {
            spatialAudioEngine?.stop()
            logger.info("🎵 Spatial audio disabled")
        }
    }

    /// Toggle modulation-based entrainment on/off
    func toggleModulationEntrainment() {
        modulationEntrainmentEnabled.toggle()

        if modulationEntrainmentEnabled {
            entrainmentFrequency = currentBrainwaveTarget.frequency
            logger.info("🌊 Modulation entrainment enabled: \(self.currentBrainwaveTarget.rawValue) (\(self.entrainmentFrequency) Hz)")
        } else {
            logger.info("🌊 Modulation entrainment disabled")
        }
    }

    /// Set brainwave target for modulation-based entrainment
    /// - Parameter target: Target brainwave state (delta, theta, alpha, beta, gamma)
    func setBrainwaveTarget(_ target: BrainwaveTarget) {
        currentBrainwaveTarget = target
        entrainmentFrequency = target.frequency
        logger.info("🧠 Brainwave target: \(target.rawValue) (\(target.frequency) Hz)")
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

    /// Adapt modulation frequency based on HRV coherence
    /// Maps coherence (0-100) to optimal brainwave targets
    /// - Parameter coherence: HRV coherence score (0-100)
    private func adaptToBiofeedback(coherence: Double) {
        guard modulationEntrainmentEnabled else { return }

        // Map HRV coherence to optimal entrainment frequency
        // Low coherence → promote Alpha (relaxation)
        // Medium coherence → Alpha-Beta transition
        // High coherence → maintain Beta (focus)
        if coherence < 40 {
            entrainmentFrequency = BrainwaveTarget.alpha.frequency
        } else if coherence < 60 {
            entrainmentFrequency = 15.0  // Alpha-Beta blend
        } else {
            entrainmentFrequency = BrainwaveTarget.beta.frequency
        }

        logger.debug("💓 HRV coherence \(Int(coherence)) → entrainment \(self.entrainmentFrequency) Hz")
    }


    /// Start bio-parameter mapping (HRV/HR → Audio/Visual modulations)
    private func startBioParameterMapping() {
        guard healthKitManager != nil else {
            logger.warning("⚠️ Bio-parameter mapping: HealthKit not connected")
            return
        }

        // Update bio-parameters every 100ms
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBioParameters()
            }
            .store(in: &cancellables)

        logger.info("🎛️ Bio-parameter mapping started")
    }

    /// Stop bio-parameter mapping
    private func stopBioParameterMapping() {
        // Cancellables will be cleared when engine stops
        logger.info("🎛️ Bio-parameter mapping stopped")
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
    }


    // MARK: - Utility Methods

    /// Get human-readable description of current state
    var stateDescription: String {
        if !isRunning {
            return "Audio engine stopped"
        }

        var description = "Microphone: Active"

        if modulationEntrainmentEnabled {
            description += "\nEntrainment: \(currentBrainwaveTarget.rawValue) (\(entrainmentFrequency) Hz)"
        } else {
            description += "\nEntrainment: Off"
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
}
