import Foundation
import AVFoundation
import simd
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// SPATIAL 3D BLENDER - CUBE-STYLE VISUAL MIXER
// ═══════════════════════════════════════════════════════════════════════════════
//
// Inspired by Lunacy Audio's CUBE:
// • 8 audio sources positioned in 3D space (cube vertices)
// • Blend between sources by moving a point in the 3D field
// • Orbits: Motion presets that animate the blend point
// • Bio-reactive: HRV/coherence influences orbit speed and path
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - 3D Position

/// Position in 3D blend space (normalized 0-1)
struct BlendPosition3D: Equatable {
    var x: Float  // Left-Right (0 = left, 1 = right)
    var y: Float  // Down-Up (0 = down, 1 = up)
    var z: Float  // Back-Front (0 = back, 1 = front)

    static let center = BlendPosition3D(x: 0.5, y: 0.5, z: 0.5)

    var simdVector: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }

    init(x: Float, y: Float, z: Float) {
        self.x = max(0, min(1, x))
        self.y = max(0, min(1, y))
        self.z = max(0, min(1, z))
    }

    init(simd: SIMD3<Float>) {
        self.x = max(0, min(1, simd.x))
        self.y = max(0, min(1, simd.y))
        self.z = max(0, min(1, simd.z))
    }

    /// Distance to another position
    func distance(to other: BlendPosition3D) -> Float {
        return simd_distance(self.simdVector, other.simdVector)
    }
}

// MARK: - Audio Source Slot

/// An audio source in the 3D blend space
struct BlendSource: Identifiable {
    let id: UUID
    var name: String
    var position: BlendPosition3D  // Fixed position in cube (vertex)
    var audioBuffer: AVAudioPCMBuffer?
    var audioFile: URL?
    var isLoaded: Bool = false
    var color: BlendSourceColor

    // Playback state
    var isPlaying: Bool = false
    var currentGain: Float = 0.0  // Calculated from blend position

    enum BlendSourceColor: String, CaseIterable {
        case red, orange, yellow, green, cyan, blue, purple, pink

        var hue: Float {
            switch self {
            case .red: return 0.0
            case .orange: return 0.08
            case .yellow: return 0.16
            case .green: return 0.33
            case .cyan: return 0.5
            case .blue: return 0.66
            case .purple: return 0.75
            case .pink: return 0.9
            }
        }
    }
}

// MARK: - Orbit Motion Presets

/// Predefined motion paths for the blend point
enum OrbitPreset: String, CaseIterable, Identifiable {
    case stationary = "Stationary"
    case circular = "Circular"
    case figure8 = "Figure 8"
    case spiral = "Spiral"
    case random = "Random Walk"
    case breathing = "Breathing" // Synced to breath rate
    case heartbeat = "Heartbeat" // Synced to heart rate
    case coherence = "Coherence Flow" // Follows HRV coherence

    var id: String { rawValue }

    var description: String {
        switch self {
        case .stationary: return "No movement"
        case .circular: return "Smooth circular motion"
        case .figure8: return "Infinity loop path"
        case .spiral: return "Expanding/contracting spiral"
        case .random: return "Organic random movement"
        case .breathing: return "Synced to your breath"
        case .heartbeat: return "Pulsing with your heart"
        case .coherence: return "Flows with HRV coherence"
        }
    }
}

// MARK: - Spatial 3D Blender

@MainActor
class Spatial3DBlender: ObservableObject {

    // MARK: - Published State

    /// Current blend position in 3D space
    @Published var blendPosition: BlendPosition3D = .center

    /// All 8 audio source slots (cube vertices)
    @Published var sources: [BlendSource] = []

    /// Current orbit motion preset
    @Published var currentOrbit: OrbitPreset = .stationary

    /// Orbit speed multiplier (0.1 - 3.0)
    @Published var orbitSpeed: Float = 1.0

    /// Whether orbit is currently active
    @Published var isOrbitActive: Bool = false

    /// Master output gain (0.0 - 1.0)
    @Published var masterGain: Float = 0.8

    /// Crossfade curve type
    @Published var crossfadeCurve: CrossfadeCurve = .equal

    // MARK: - Bio-Reactive State

    /// Current biofeedback data
    private var currentBioSignal = BioSignal()

    /// Bio-reactivity amount (0.0 - 1.0)
    @Published var bioReactivity: Float = 0.5

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var mixerNode: AVAudioMixerNode?
    private var isEngineRunning = false

    // MARK: - Orbit Animation

    private var orbitTimer: Timer?
    private var orbitPhase: Float = 0.0
    private var orbitStartTime: Date?

    // MARK: - Crossfade Curves

    enum CrossfadeCurve: String, CaseIterable {
        case linear = "Linear"
        case equal = "Equal Power"
        case sCurve = "S-Curve"
        case exponential = "Exponential"

        func apply(_ distance: Float, maxDistance: Float) -> Float {
            let normalized = 1.0 - min(distance / maxDistance, 1.0)

            switch self {
            case .linear:
                return normalized
            case .equal:
                // Equal power crossfade (maintains constant perceived volume)
                return cos((1.0 - normalized) * Float.pi / 2)
            case .sCurve:
                // Smooth S-curve
                return normalized * normalized * (3.0 - 2.0 * normalized)
            case .exponential:
                // Exponential falloff
                return pow(normalized, 2.0)
            }
        }
    }

    // MARK: - Initialization

    init() {
        setupDefaultSources()
        setupAudioEngine()
    }

    deinit {
        stopOrbit()
        stopAudioEngine()
    }

    // MARK: - Setup

    /// Setup 8 source slots at cube vertices
    private func setupDefaultSources() {
        let positions: [(Float, Float, Float)] = [
            (0, 0, 0), // Back-Bottom-Left
            (1, 0, 0), // Back-Bottom-Right
            (0, 1, 0), // Back-Top-Left
            (1, 1, 0), // Back-Top-Right
            (0, 0, 1), // Front-Bottom-Left
            (1, 0, 1), // Front-Bottom-Right
            (0, 1, 1), // Front-Top-Left
            (1, 1, 1), // Front-Top-Right
        ]

        let colors = BlendSource.BlendSourceColor.allCases

        sources = positions.enumerated().map { index, pos in
            BlendSource(
                id: UUID(),
                name: "Slot \(index + 1)",
                position: BlendPosition3D(x: pos.0, y: pos.1, z: pos.2),
                color: colors[index % colors.count]
            )
        }
    }

    /// Setup AVAudioEngine for playback
    private func setupAudioEngine() {
        mixerNode = AVAudioMixerNode()
        guard let mixer = mixerNode else { return }

        audioEngine.attach(mixer)
        audioEngine.connect(mixer, to: audioEngine.mainMixerNode, format: nil)

        // Create player nodes for each source
        for source in sources {
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: mixer, format: nil)
            playerNodes[source.id] = player
        }

        audioEngine.prepare()
    }

    // MARK: - Source Management

    /// Load audio file into a source slot
    func loadAudio(url: URL, into slotIndex: Int) async throws {
        guard slotIndex >= 0 && slotIndex < sources.count else {
            throw BlenderError.invalidSlotIndex
        }

        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw BlenderError.bufferCreationFailed
        }

        try file.read(into: buffer)

        sources[slotIndex].audioBuffer = buffer
        sources[slotIndex].audioFile = url
        sources[slotIndex].isLoaded = true
        sources[slotIndex].name = url.deletingPathExtension().lastPathComponent

        print("🎛️ Loaded '\(sources[slotIndex].name)' into slot \(slotIndex + 1)")
    }

    /// Clear a source slot
    func clearSlot(_ slotIndex: Int) {
        guard slotIndex >= 0 && slotIndex < sources.count else { return }

        if let player = playerNodes[sources[slotIndex].id] {
            player.stop()
        }

        sources[slotIndex].audioBuffer = nil
        sources[slotIndex].audioFile = nil
        sources[slotIndex].isLoaded = false
        sources[slotIndex].name = "Slot \(slotIndex + 1)"
    }

    // MARK: - Blend Calculation

    /// Calculate gain for each source based on blend position
    func calculateBlendGains() -> [UUID: Float] {
        var gains: [UUID: Float] = [:]
        let maxDistance: Float = sqrt(3.0) // Diagonal of unit cube

        for source in sources {
            let distance = blendPosition.distance(to: source.position)
            let gain = crossfadeCurve.apply(distance, maxDistance: maxDistance)
            gains[source.id] = gain * masterGain
        }

        return gains
    }

    /// Update source gains based on current blend position
    func updateBlendGains() {
        let gains = calculateBlendGains()

        for i in 0..<sources.count {
            if let gain = gains[sources[i].id] {
                sources[i].currentGain = gain

                // Update audio player volume
                if let player = playerNodes[sources[i].id] {
                    player.volume = gain
                }
            }
        }
    }

    // MARK: - Orbit Animation

    /// Start orbit motion
    func startOrbit() {
        guard currentOrbit != .stationary else { return }

        isOrbitActive = true
        orbitStartTime = Date()
        orbitPhase = 0.0

        // 60 FPS update for smooth motion
        orbitTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateOrbit()
            }
        }

        print("🌀 Orbit started: \(currentOrbit.rawValue)")
    }

    /// Stop orbit motion
    func stopOrbit() {
        orbitTimer?.invalidate()
        orbitTimer = nil
        isOrbitActive = false

        print("🌀 Orbit stopped")
    }

    /// Update orbit position
    private func updateOrbit() {
        guard isOrbitActive else { return }

        let dt: Float = 1.0 / 60.0
        let speedMultiplier = orbitSpeed * (1.0 + bioReactivity * (currentBioSignal.energy - 0.5))
        orbitPhase += dt * speedMultiplier

        let newPosition: BlendPosition3D

        switch currentOrbit {
        case .stationary:
            return

        case .circular:
            let radius: Float = 0.3
            let x = 0.5 + radius * cos(orbitPhase * 2.0)
            let z = 0.5 + radius * sin(orbitPhase * 2.0)
            newPosition = BlendPosition3D(x: x, y: 0.5, z: z)

        case .figure8:
            let t = orbitPhase * 1.5
            let x = 0.5 + 0.3 * sin(t)
            let z = 0.5 + 0.3 * sin(t * 2.0)
            newPosition = BlendPosition3D(x: x, y: 0.5, z: z)

        case .spiral:
            let radius = 0.1 + 0.3 * abs(sin(orbitPhase * 0.3))
            let x = 0.5 + radius * cos(orbitPhase * 2.0)
            let z = 0.5 + radius * sin(orbitPhase * 2.0)
            let y = 0.5 + 0.2 * sin(orbitPhase * 0.5)
            newPosition = BlendPosition3D(x: x, y: y, z: z)

        case .random:
            // Perlin noise-like smooth random movement
            let noise = sin(orbitPhase * 1.3) * cos(orbitPhase * 0.7) * sin(orbitPhase * 2.1)
            let x = 0.5 + 0.3 * sin(orbitPhase + noise)
            let y = 0.5 + 0.2 * cos(orbitPhase * 0.8 + noise)
            let z = 0.5 + 0.3 * sin(orbitPhase * 1.2 - noise)
            newPosition = BlendPosition3D(x: x, y: y, z: z)

        case .breathing:
            // Synced to breath rate (12-20 BPM typical)
            let breathRate = max(currentBioSignal.breathRate, 12.0)
            let breathPhase = orbitPhase * Float(breathRate) / 60.0 * Float.pi * 2
            let breathDepth = (sin(breathPhase) + 1.0) / 2.0
            newPosition = BlendPosition3D(x: 0.5, y: breathDepth, z: 0.5)

        case .heartbeat:
            // Synced to heart rate
            let heartRate = max(currentBioSignal.heartRate, 60.0)
            let heartPhase = orbitPhase * Float(heartRate) / 60.0 * Float.pi * 2
            // Sharp attack, slow decay (like a heartbeat)
            let pulse = pow(max(0, sin(heartPhase)), 0.5)
            let radius = 0.1 + 0.3 * pulse
            newPosition = BlendPosition3D(x: 0.5 + radius * 0.5, y: 0.5 + pulse * 0.3, z: 0.5)

        case .coherence:
            // Movement influenced by HRV coherence
            let coherence = currentBioSignal.coherence
            let smoothness = coherence / 100.0  // High coherence = smoother movement
            let chaos = 1.0 - smoothness

            let baseX = 0.5 + 0.3 * sin(orbitPhase)
            let baseZ = 0.5 + 0.3 * cos(orbitPhase)
            let noiseX = chaos * 0.2 * sin(orbitPhase * 7.0)
            let noiseZ = chaos * 0.2 * cos(orbitPhase * 5.0)

            newPosition = BlendPosition3D(
                x: baseX + noiseX,
                y: 0.5 + Float(coherence / 200.0),
                z: baseZ + noiseZ
            )
        }

        blendPosition = newPosition
        updateBlendGains()
    }

    // MARK: - Bio-Reactivity

    /// Update with new bio-signal data
    func updateBioSignal(_ signal: BioSignal) {
        currentBioSignal = signal

        // Bio-reactive orbit speed adjustment
        if bioReactivity > 0 {
            let energyFactor = 1.0 + (signal.energy - 0.5) * bioReactivity
            // Orbit speed is influenced by energy level
            _ = orbitSpeed * energyFactor
        }
    }

    // MARK: - Playback Control

    /// Start all loaded sources
    func startPlayback() throws {
        if !isEngineRunning {
            try audioEngine.start()
            isEngineRunning = true
        }

        for source in sources where source.isLoaded {
            guard let buffer = source.audioBuffer,
                  let player = playerNodes[source.id] else { continue }

            // Schedule buffer for looped playback
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
        }

        updateBlendGains()
        print("▶️ 3D Blender playback started")
    }

    /// Stop all playback
    func stopPlayback() {
        for player in playerNodes.values {
            player.stop()
        }

        print("⏹️ 3D Blender playback stopped")
    }

    /// Stop audio engine
    private func stopAudioEngine() {
        stopPlayback()
        audioEngine.stop()
        isEngineRunning = false
    }

    // MARK: - Preset Management

    /// Save current configuration as preset
    func savePreset(name: String) -> BlenderPreset {
        return BlenderPreset(
            name: name,
            blendPosition: blendPosition,
            orbit: currentOrbit,
            orbitSpeed: orbitSpeed,
            crossfadeCurve: crossfadeCurve,
            bioReactivity: bioReactivity,
            sourceFiles: sources.compactMap { $0.audioFile }
        )
    }

    /// Load preset
    func loadPreset(_ preset: BlenderPreset) async throws {
        blendPosition = preset.blendPosition
        currentOrbit = preset.orbit
        orbitSpeed = preset.orbitSpeed
        crossfadeCurve = preset.crossfadeCurve
        bioReactivity = preset.bioReactivity

        // Load audio files
        for (index, url) in preset.sourceFiles.prefix(8).enumerated() {
            try await loadAudio(url: url, into: index)
        }

        updateBlendGains()
    }

    // MARK: - Errors

    enum BlenderError: Error, LocalizedError {
        case invalidSlotIndex
        case bufferCreationFailed
        case fileLoadFailed

        var errorDescription: String? {
            switch self {
            case .invalidSlotIndex: return "Invalid source slot index"
            case .bufferCreationFailed: return "Failed to create audio buffer"
            case .fileLoadFailed: return "Failed to load audio file"
            }
        }
    }
}

// MARK: - Blender Preset

struct BlenderPreset: Codable, Identifiable {
    let id: UUID
    let name: String
    let blendPosition: BlendPosition3D
    let orbit: OrbitPreset
    let orbitSpeed: Float
    let crossfadeCurve: Spatial3DBlender.CrossfadeCurve
    let bioReactivity: Float
    let sourceFiles: [URL]
    let createdAt: Date

    init(name: String, blendPosition: BlendPosition3D, orbit: OrbitPreset,
         orbitSpeed: Float, crossfadeCurve: Spatial3DBlender.CrossfadeCurve,
         bioReactivity: Float, sourceFiles: [URL]) {
        self.id = UUID()
        self.name = name
        self.blendPosition = blendPosition
        self.orbit = orbit
        self.orbitSpeed = orbitSpeed
        self.crossfadeCurve = crossfadeCurve
        self.bioReactivity = bioReactivity
        self.sourceFiles = sourceFiles
        self.createdAt = Date()
    }
}

// MARK: - Codable Conformance

extension BlendPosition3D: Codable {}
extension OrbitPreset: Codable {}
extension Spatial3DBlender.CrossfadeCurve: Codable {}
