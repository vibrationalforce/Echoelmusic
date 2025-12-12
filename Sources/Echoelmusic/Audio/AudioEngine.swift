import Foundation
import AVFoundation
import Combine

/// Central audio engine that manages and mixes multiple audio sources
///
/// Coordinates:
/// - Microphone input (for voice/breath capture)
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

    /// Whether spatial audio is enabled
    @Published var spatialAudioEnabled: Bool = false

    /// Modulation rate for aesthetic effects (Hz)
    @Published var modulationRate: Float = 1.0

    /// Modulation depth (0.0 - 1.0)
    @Published var modulationDepth: Float = 0.3


    // MARK: - Audio Components

    /// Microphone manager for voice/breath input
    let microphoneManager: MicrophoneManager

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

    /// Reference to EchoelSync for OSC routing
    private weak var echoelSync: EchoelSync?


    // MARK: - Private Properties

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization

    init(microphoneManager: MicrophoneManager) {
        self.microphoneManager = microphoneManager

        // Configure audio session for optimal performance
        do {
            try AudioConfiguration.configureAudioSession()
            print(AudioConfiguration.latencyStats())
        } catch {
            print("⚠️  Failed to configure audio session: \(error)")
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
            print("⚠️  Spatial audio engine requires iOS 15+")
        }

        // Start monitoring device capabilities
        deviceCapabilities?.startMonitoringAudioRoute()

        // Connect to EchoelSync for OSC routing
        echoelSync = EchoelSync.shared

        print("🎵 AudioEngine initialized")
        print("   Spatial Audio: \(deviceCapabilities?.canUseSpatialAudio == true ? "✅" : "❌")")
        print("   Head Tracking: \(headTrackingManager?.isAvailable == true ? "✅" : "❌")")
        print("   EchoelSync: Connected for OSC routing")
    }


    // MARK: - Public Methods

    /// Start the audio engine (microphone + spatial audio)
    func start() {
        // Start microphone
        microphoneManager.startRecording()

        // Start spatial audio if enabled
        if spatialAudioEnabled, let spatial = spatialAudioEngine {
            do {
                try spatial.start()
                print("🎵 Spatial audio started")
            } catch {
                print("❌ Failed to start spatial audio: \(error)")
                spatialAudioEnabled = false
            }
        }

        // Start bio-parameter mapping updates
        startBioParameterMapping()

        isRunning = true
        print("🎵 AudioEngine started")
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
        print("AudioEngine stopped")
    }

    /// Set modulation rate for aesthetic effects
    /// - Parameter rate: Rate in Hz (0.1 - 20.0)
    func setModulationRate(_ rate: Float) {
        modulationRate = min(max(rate, 0.1), 20.0)
    }

    /// Set modulation depth for aesthetic effects
    /// - Parameter depth: Depth (0.0 - 1.0)
    func setModulationDepth(_ depth: Float) {
        modulationDepth = min(max(depth, 0.0), 1.0)
    }

    /// Toggle spatial audio on/off
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()

        if spatialAudioEnabled {
            if let spatial = spatialAudioEngine {
                do {
                    try spatial.start()
                    print("🎵 Spatial audio enabled")
                } catch {
                    print("❌ Failed to enable spatial audio: \(error)")
                    spatialAudioEnabled = false
                }
            } else {
                print("⚠️  Spatial audio not available")
                spatialAudioEnabled = false
            }
        } else {
            spatialAudioEngine?.stop()
            print("🎵 Spatial audio disabled")
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

    /// Adapt modulation based on HRV coherence
    /// - Parameter coherence: HRV coherence score (0-100)
    private func adaptToBiofeedback(coherence: Double) {
        // Use HRV to modulate audio effects for aesthetic purposes
        let adaptiveDepth = Float(0.2 + (coherence / 100.0) * 0.3)  // 0.2-0.5 range
        modulationDepth = adaptiveDepth
    }


    /// Start bio-parameter mapping (HRV/HR → Audio)
    private func startBioParameterMapping() {
        guard let healthKit = healthKitManager else {
            print("⚠️  Bio-parameter mapping: HealthKit not connected")
            return
        }

        // Update bio-parameters every 100ms
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBioParameters()
            }
            .store(in: &cancellables)

        print("🎛️  Bio-parameter mapping started")
    }

    /// Stop bio-parameter mapping
    private func stopBioParameterMapping() {
        // Cancellables will be cleared when engine stops
        print("🎛️  Bio-parameter mapping stopped")
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

        // Apply modulation based on bio parameters
        modulationDepth = bioParameterMapper.amplitude
        modulationRate = bioParameterMapper.baseFrequency / 100.0  // Scale to aesthetic range
    }


    // MARK: - Utility Methods

    /// Get human-readable description of current state
    var stateDescription: String {
        if !isRunning {
            return "Audio engine stopped"
        }

        var description = "Microphone: Active"
        description += "\nModulation: \(String(format: "%.1f", modulationRate)) Hz @ \(String(format: "%.0f", modulationDepth * 100))%"

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
