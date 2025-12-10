import Foundation
import AVFoundation
import Combine

/// SpatialAudioRenderer - Integration Layer
/// Connects SpatialAudioEngine with UnifiedControlHub, MIDI, and Bio-data
/// Provides unified spatial audio rendering with real-time bio-reactive control
@MainActor
class SpatialAudioRenderer: ObservableObject {

    // MARK: - Singleton

    static let shared = SpatialAudioRenderer()

    // MARK: - Published State

    @Published var isRendering: Bool = false
    @Published var currentProfile: RenderProfile = .performance
    @Published var spatialQuality: SpatialQuality = .high
    @Published var bioReactiveEnabled: Bool = true

    // MARK: - Components

    private let spatialEngine: SpatialAudioEngine
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Configuration

    struct RenderConfig {
        var sampleRate: Double = 48000
        var bufferSize: Int = 256
        var maxSources: Int = 16
        var updateRate: Double = 60.0  // Hz
        var hrtfEnabled: Bool = true
        var ambisonicsOrder: Int = 1   // First-order ambisonics
    }

    private var config = RenderConfig()

    // MARK: - Render Profiles

    enum RenderProfile: String, CaseIterable {
        case lowLatency = "Low Latency"      // Gaming, live performance
        case balanced = "Balanced"            // General use
        case performance = "Performance"      // Studio, high quality
        case immersive = "Immersive"         // VR/AR, full spatial

        var config: RenderConfig {
            switch self {
            case .lowLatency:
                return RenderConfig(
                    sampleRate: 48000,
                    bufferSize: 128,
                    maxSources: 8,
                    updateRate: 120.0,
                    hrtfEnabled: false,
                    ambisonicsOrder: 0
                )
            case .balanced:
                return RenderConfig(
                    sampleRate: 48000,
                    bufferSize: 256,
                    maxSources: 16,
                    updateRate: 60.0,
                    hrtfEnabled: true,
                    ambisonicsOrder: 1
                )
            case .performance:
                return RenderConfig(
                    sampleRate: 48000,
                    bufferSize: 512,
                    maxSources: 32,
                    updateRate: 60.0,
                    hrtfEnabled: true,
                    ambisonicsOrder: 3
                )
            case .immersive:
                return RenderConfig(
                    sampleRate: 96000,
                    bufferSize: 256,
                    maxSources: 64,
                    updateRate: 90.0,
                    hrtfEnabled: true,
                    ambisonicsOrder: 5
                )
            }
        }
    }

    // MARK: - Spatial Quality

    enum SpatialQuality: String, CaseIterable {
        case low = "Low"           // Stereo panning only
        case medium = "Medium"     // Basic 3D positioning
        case high = "High"         // HRTF rendering
        case ultra = "Ultra"       // Full ambisonics + room simulation

        var description: String {
            switch self {
            case .low: return "Stereo (CPU efficient)"
            case .medium: return "3D positioning"
            case .high: return "HRTF binaural"
            case .ultra: return "Ambisonics + Room"
            }
        }
    }

    // MARK: - Bio-Reactive Mapping

    struct BioSpatialMapping {
        var hrvToFieldMorphSpeed: Float = 0.5    // HRV coherence -> field animation speed
        var heartRateToSourceSpread: Float = 1.0 // HR -> source distribution radius
        var breathToElevation: Float = 0.3       // Breathing -> vertical movement
        var coherenceToFieldGeometry: Bool = true // Auto-switch geometry based on coherence

        // Coherence thresholds for geometry switching
        var lowCoherenceGeometry: SpatialAudioEngine.AFAFieldGeometry = .grid(rows: 4, cols: 4)
        var mediumCoherenceGeometry: SpatialAudioEngine.AFAFieldGeometry = .circle(radius: 2.0)
        var highCoherenceGeometry: SpatialAudioEngine.AFAFieldGeometry = .fibonacci(count: 16)
    }

    private var bioMapping = BioSpatialMapping()

    // MARK: - Current Bio State

    private var currentHRV: Double = 50.0
    private var currentHeartRate: Double = 70.0
    private var currentCoherence: Double = 50.0
    private var currentBreathPhase: Double = 0.0

    // MARK: - Initialization

    private init() {
        self.spatialEngine = SpatialAudioEngine()
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe spatial engine state
        spatialEngine.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.isRendering = isActive
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func start() throws {
        guard !isRendering else { return }

        // Apply current profile config
        config = currentProfile.config

        // Configure spatial engine mode based on quality
        switch spatialQuality {
        case .low:
            spatialEngine.setMode(.stereo)
        case .medium:
            spatialEngine.setMode(.surround_3d)
        case .high:
            spatialEngine.setMode(.binaural)
        case .ultra:
            spatialEngine.setMode(.ambisonics)
        }

        // Start spatial engine
        try spatialEngine.start()

        // Start update timer
        startUpdateLoop()

        print("SpatialAudioRenderer started (profile: \(currentProfile.rawValue), quality: \(spatialQuality.rawValue))")
    }

    func stop() {
        stopUpdateLoop()
        spatialEngine.stop()
        print("SpatialAudioRenderer stopped")
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        let interval = 1.0 / config.updateRate

        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func update() {
        guard isRendering else { return }

        // Update 4D orbital motion
        if spatialEngine.currentMode == .surround_4d {
            spatialEngine.update4DOrbitalMotion(deltaTime: 1.0 / config.updateRate)
        }

        // Apply bio-reactive updates
        if bioReactiveEnabled {
            applyBioReactiveUpdates()
        }
    }

    // MARK: - Bio-Reactive Integration

    func updateBioData(hrv: Double, heartRate: Double, coherence: Double, breathPhase: Double = 0.0) {
        currentHRV = hrv
        currentHeartRate = heartRate
        currentCoherence = coherence
        currentBreathPhase = breathPhase
    }

    private func applyBioReactiveUpdates() {
        // Apply field geometry based on coherence
        if bioMapping.coherenceToFieldGeometry && spatialEngine.currentMode == .afa {
            let geometry: SpatialAudioEngine.AFAFieldGeometry

            if currentCoherence < 40 {
                geometry = bioMapping.lowCoherenceGeometry
            } else if currentCoherence < 70 {
                geometry = bioMapping.mediumCoherenceGeometry
            } else {
                geometry = bioMapping.highCoherenceGeometry
            }

            spatialEngine.applyAFAField(geometry: geometry, coherence: currentCoherence)
        }

        // Apply breathing to elevation (Y-axis)
        let breathOffset = sin(currentBreathPhase * 2.0 * .pi) * bioMapping.breathToElevation

        // Update all source positions with breath modulation
        for source in spatialEngine.spatialSources {
            var newPosition = source.position
            newPosition.y += Float(breathOffset)
            spatialEngine.updateSourcePosition(id: source.id, position: newPosition)
        }
    }

    // MARK: - Source Management (Forwarding)

    func addSpatialSource(position: SIMD3<Float>, amplitude: Float = 1.0, frequency: Float = 440.0) -> UUID {
        return spatialEngine.addSource(position: position, amplitude: amplitude, frequency: frequency)
    }

    func removeSpatialSource(id: UUID) {
        spatialEngine.removeSource(id: id)
    }

    func updateSourcePosition(id: UUID, position: SIMD3<Float>) {
        spatialEngine.updateSourcePosition(id: id, position: position)
    }

    func setOrbitalMotion(id: UUID, radius: Float, speed: Float, phase: Float = 0) {
        spatialEngine.updateSourceOrbital(id: id, radius: radius, speed: speed, phase: phase)
    }

    // MARK: - MIDI Integration

    /// Map MIDI note to spatial position
    func handleMIDINote(note: UInt8, velocity: Float, channel: UInt8) {
        // Note number -> azimuth (0-127 maps to full circle)
        let azimuth = Float(note) / 127.0 * 2.0 * .pi

        // Velocity -> distance (louder = closer)
        let distance = 1.0 + (1.0 - velocity) * 4.0  // 1m to 5m

        // Channel -> elevation (0-15 maps to -1 to +1)
        let elevation = (Float(channel) / 15.0 - 0.5) * 2.0

        // Convert spherical to Cartesian
        let x = distance * cos(azimuth) * cos(elevation)
        let y = distance * sin(elevation)
        let z = distance * sin(azimuth) * cos(elevation)

        let position = SIMD3<Float>(x, y, z)

        // Add or update source
        let _ = addSpatialSource(position: position, amplitude: velocity, frequency: midiToFrequency(note))
    }

    private func midiToFrequency(_ note: UInt8) -> Float {
        // A4 = 440 Hz, MIDI note 69
        return 440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
    }

    // MARK: - Profile & Quality Management

    func setProfile(_ profile: RenderProfile) {
        currentProfile = profile
        config = profile.config

        if isRendering {
            // Restart with new profile
            stop()
            try? start()
        }

        print("Render profile: \(profile.rawValue)")
    }

    func setQuality(_ quality: SpatialQuality) {
        spatialQuality = quality

        // Update spatial engine mode
        switch quality {
        case .low:
            spatialEngine.setMode(.stereo)
        case .medium:
            spatialEngine.setMode(.surround_3d)
        case .high:
            spatialEngine.setMode(.binaural)
        case .ultra:
            spatialEngine.setMode(.ambisonics)
        }

        print("Spatial quality: \(quality.rawValue)")
    }

    // MARK: - AFA Field Control

    func setAFAMode() {
        spatialEngine.setMode(.afa)
    }

    func applyAFAGeometry(_ geometry: SpatialAudioEngine.AFAFieldGeometry) {
        spatialEngine.applyAFAField(geometry: geometry, coherence: currentCoherence)
    }

    // MARK: - Head Tracking

    func enableHeadTracking(_ enabled: Bool) {
        spatialEngine.headTrackingEnabled = enabled
    }

    // MARK: - Debug

    var debugInfo: String {
        """
        SpatialAudioRenderer:
        - Rendering: \(isRendering ? "Yes" : "No")
        - Profile: \(currentProfile.rawValue)
        - Quality: \(spatialQuality.rawValue)
        - Bio-Reactive: \(bioReactiveEnabled ? "Yes" : "No")
        - Sources: \(spatialEngine.spatialSources.count)
        - Update Rate: \(config.updateRate) Hz
        - HRV/Coherence: \(Int(currentHRV))/\(Int(currentCoherence))

        \(spatialEngine.debugInfo)
        """
    }
}
