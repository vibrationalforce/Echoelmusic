import Foundation
import AVFoundation
import Combine

/// Central audio engine that manages and mixes multiple audio sources
///
/// Coordinates:
/// - Microphone input (for voice/breath capture)
/// - Binaural beat generation (for brainwave entrainment)
/// - Spatial audio with head tracking
/// - Bio-parameter mapping (HRV → Audio)
/// - Real-time mixing and effects
///
/// This class acts as the central hub for all audio processing in Echoelmusic
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class AudioEngine {

    // MARK: - Observable Properties

    /// Whether the audio engine is currently running
    var isRunning: Bool = false

    /// Whether binaural beats are enabled
    var binauralBeatsEnabled: Bool = false

    /// Whether spatial audio is enabled
    var spatialAudioEnabled: Bool = false

    /// Current binaural beat state
    var currentBrainwaveState: BinauralBeatGenerator.BrainwaveState = .alpha

    /// Binaural beat amplitude (0.0 - 1.0)
    var binauralAmplitude: Float = 0.3


    // MARK: - Audio Components

    /// Microphone manager for voice/breath input
    let microphoneManager: MicrophoneManager

    /// Binaural beat generator for healing frequencies
    private let binauralGenerator = BinauralBeatGenerator()

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
            #if DEBUG
            debugLog("🎵", AudioConfiguration.latencyStats())
            #endif
        } catch {
            #if DEBUG
            debugLog("⚠️", "Failed to configure audio session: \(error)")
            #endif
        }

        // Set real-time audio thread priority
        AudioConfiguration.setAudioThreadPriority()

        // Configure default binaural beat settings
        binauralGenerator.configure(
            carrier: 432.0,  // Healing frequency
            beat: 10.0,      // Alpha waves (relaxation)
            amplitude: 0.3
        )

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
            #if DEBUG
            debugLog("⚠️", "Spatial audio engine requires iOS 15+")
            #endif
        }

        // Start monitoring device capabilities
        deviceCapabilities?.startMonitoringAudioRoute()

        // Initialize node graph with default biofeedback chain
        nodeGraph = NodeGraph.createBiofeedbackChain()

        #if DEBUG
        debugLog("🎵", "AudioEngine initialized")
        debugLog("🎵", "   Spatial Audio: \(deviceCapabilities?.canUseSpatialAudio == true ? "✅" : "❌")")
        debugLog("🎵", "   Head Tracking: \(headTrackingManager?.isAvailable == true ? "✅" : "❌")")
        debugLog("🎵", "   Node Graph: \(nodeGraph?.nodes.count ?? 0) nodes loaded")
        #endif
    }


    // MARK: - Public Methods

    /// Start the audio engine (microphone + optional binaural beats + spatial audio)
    func start() {
        // Start microphone
        microphoneManager.startRecording()

        // Start binaural beats if enabled
        if binauralBeatsEnabled {
            binauralGenerator.start()
        }

        // Start spatial audio if enabled
        if spatialAudioEnabled, let spatial = spatialAudioEngine {
            do {
                try spatial.start()
                #if DEBUG
                debugLog("🎵", "Spatial audio started")
                #endif
            } catch {
                #if DEBUG
                debugLog("❌", "Failed to start spatial audio: \(error)")
                #endif
                spatialAudioEnabled = false
            }
        }

        // Start bio-parameter mapping updates
        startBioParameterMapping()

        isRunning = true
        #if DEBUG
        debugLog("🎵", "AudioEngine started")
        #endif
    }

    /// Stop the audio engine
    func stop() {
        // Stop microphone
        microphoneManager.stopRecording()

        // Stop binaural beats
        binauralGenerator.stop()

        // Stop spatial audio
        spatialAudioEngine?.stop()

        // Stop bio-parameter mapping
        stopBioParameterMapping()

        isRunning = false
        #if DEBUG
        debugLog("🎵", "AudioEngine stopped")
        #endif
    }

    /// Toggle binaural beats on/off
    func toggleBinauralBeats() {
        binauralBeatsEnabled.toggle()

        if binauralBeatsEnabled {
            binauralGenerator.start()
            #if DEBUG
            debugLog("🔊", "Binaural beats enabled")
            #endif
        } else {
            binauralGenerator.stop()
            #if DEBUG
            debugLog("🔇", "Binaural beats disabled")
            #endif
        }
    }

    /// Set brainwave state for binaural beats
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
                    #if DEBUG
                    debugLog("🎵", "Spatial audio enabled")
                    #endif
                } catch {
                    #if DEBUG
                    debugLog("❌", "Failed to enable spatial audio: \(error)")
                    #endif
                    spatialAudioEnabled = false
                }
            } else {
                #if DEBUG
                debugLog("⚠️", "Spatial audio not available")
                #endif
                spatialAudioEnabled = false
            }
        } else {
            spatialAudioEngine?.stop()
            #if DEBUG
            debugLog("🎵", "Spatial audio disabled")
            #endif
        }
    }

    /// Connect to HealthKit manager for HRV-based adaptations
    /// - Parameter healthKitManager: HealthKit manager instance
    func connectHealthKit(_ healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        #if DEBUG
        debugLog("🔗", "Connected HealthKit manager for biofeedback")
        #endif
        // Note: HRV coherence updates are now handled via polling in updateBioParameters()
        // since @Observable doesn't use Combine $ publishers
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
        guard let healthKit = healthKitManager else {
            #if DEBUG
            debugLog("⚠️", "Bio-parameter mapping: HealthKit not connected")
            #endif
            return
        }

        // Update bio-parameters every 100ms
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBioParameters()
            }
            .store(in: &cancellables)

        #if DEBUG
        debugLog("🎛️", "Bio-parameter mapping started")
        #endif
    }

    /// Stop bio-parameter mapping
    private func stopBioParameterMapping() {
        // Cancellables will be cleared when engine stops
        #if DEBUG
        debugLog("🎛️", "Bio-parameter mapping stopped")
        #endif
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

        // Adapt binaural beats to coherence (replaces Combine subscription)
        adaptToBiofeedback(coherence: hrvCoherence)

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
            description += "\nBinaural Beats: \(currentBrainwaveState.rawValue.capitalized) (\(currentBrainwaveState.beatFrequency) Hz)"
        } else {
            description += "\nBinaural Beats: Off"
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

// MARK: - ObservableObject Conformance (Backward Compatibility)

/// Allows AudioEngine to work with older SwiftUI code expecting ObservableObject
extension AudioEngine: ObservableObject { }
