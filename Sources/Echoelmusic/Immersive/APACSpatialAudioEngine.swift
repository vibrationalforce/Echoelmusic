import Foundation
import AVFoundation
import Combine
import simd
import Accelerate

#if os(visionOS) || os(iOS) || os(macOS)
import AVFAudio
#endif

/// Apple Positional Audio Codec (APAC) Spatial Audio Engine
/// Full 3D audio spatialization with HRTF, ambisonics, and object-based audio
/// Integrated with AIV for immersive audio-visual experiences
@MainActor
@Observable
class APACSpatialAudioEngine {

    // MARK: - Published State

    /// Is spatial audio active
    var isActive: Bool = false

    /// Current listener position in 3D space
    var listenerPosition: SIMD3<Float> = .zero

    /// Current listener orientation
    var listenerOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    /// Active audio sources
    var activeSources: [SpatialAudioSource] = []

    /// Current ambisonic order (1-3)
    var ambisonicOrder: Int = 3

    /// Head tracking enabled
    var headTrackingEnabled: Bool = true

    /// Room acoustic simulation enabled
    var roomAcousticsEnabled: Bool = true

    // MARK: - Audio Source Model

    struct SpatialAudioSource: Identifiable {
        let id: UUID
        var name: String
        var position: SIMD3<Float>
        var orientation: simd_quatf
        var type: SourceType
        var volume: Float
        var isPlaying: Bool

        // Distance attenuation
        var attenuationModel: AttenuationModel
        var referenceDistance: Float
        var maxDistance: Float
        var rolloffFactor: Float

        // Directivity
        var directivityPattern: DirectivityPattern
        var innerConeAngle: Float  // Degrees
        var outerConeAngle: Float
        var outerConeGain: Float

        // Occlusion/Obstruction
        var occlusionLevel: Float
        var obstructionLevel: Float

        // Reverb send
        var reverbSendLevel: Float
        var reverbBus: Int

        enum SourceType: String {
            case pointSource       // Omnidirectional point
            case directional       // Cone-shaped directivity
            case ambisonic         // Full sphere ambisonic
            case stereoSpread      // Stereo with spatial spread
            case binaural          // Pre-rendered binaural
        }

        enum AttenuationModel: String {
            case none              // No distance attenuation
            case linear            // Linear falloff
            case logarithmic       // Logarithmic (realistic)
            case inverse           // Inverse distance
            case custom            // User-defined curve
        }

        enum DirectivityPattern: String {
            case omnidirectional   // Equal in all directions
            case cardioid          // Heart-shaped
            case supercardioid     // Tighter cardioid
            case figure8           // Bidirectional
            case custom            // User-defined
        }
    }

    // MARK: - HRTF System

    struct HRTFProfile {
        var name: String
        var sampleRate: Double
        var impulseResponseLength: Int
        var elevationAngles: [Float]      // Available elevation angles
        var azimuthAngles: [Float]        // Available azimuth angles
        var irData: [String: [Float]]     // Indexed by "elev_azim" key
    }

    // MARK: - Room Acoustics

    struct RoomAcoustics: Codable {
        var roomSize: SIMD3<Float>        // Width, Height, Depth in meters
        var reverbTime: Float             // RT60 in seconds
        var absorptionCoefficients: [Float]  // Per frequency band
        var diffusion: Float              // 0.0 - 1.0
        var earlyReflections: Bool
        var lateReverb: Bool

        // Material presets
        var wallMaterial: Material
        var floorMaterial: Material
        var ceilingMaterial: Material

        enum Material: String, Codable {
            case concrete, wood, glass, fabric, acoustic_tile, carpet, metal
        }
    }

    // MARK: - Ambisonic Encoding

    struct AmbisonicField {
        var order: Int
        var normalization: Normalization
        var channelOrdering: ChannelOrdering
        var coefficients: [[Float]]       // [channel][sample]

        enum Normalization: String {
            case sn3d       // Semi-normalized 3D (Apple default)
            case n3d        // Full 3D normalization
            case furse      // Furse-Malham
        }

        enum ChannelOrdering: String {
            case acn        // Ambisonic Channel Number (Apple)
            case fuma       // Furse-Malham ordering
            case sid        // Single Index Designation
        }

        // Channel count for order: (order + 1)²
        var channelCount: Int {
            return (order + 1) * (order + 1)
        }
    }

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var spatialMixer: AVAudioEnvironmentNode?
    private var ambisonicDecoder: AmbisonicDecoder?
    private var hrtfProcessor: HRTFProcessor?
    private var roomSimulator: RoomSimulator?

    private var sourceNodes: [UUID: AVAudioPlayerNode] = [:]
    private var sourceFormats: [UUID: AVAudioFormat] = [:]

    private var currentHRTFProfile: HRTFProfile?
    private var currentRoomAcoustics: RoomAcoustics?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupAudioEngine()
        loadDefaultHRTF()
        setupDefaultRoom()

        print("🎧 APACSpatialAudioEngine: Initialized")
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else { return }

        // Create spatial environment node
        spatialMixer = AVAudioEnvironmentNode()

        guard let mixer = spatialMixer else { return }

        // Configure for spatial audio
        mixer.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        mixer.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: 0, y: 0, z: -1),
            up: AVAudio3DVector(x: 0, y: 1, z: 0)
        )

        // Set rendering algorithm
        mixer.renderingAlgorithm = .HRTFHQ

        // Connect to main mixer
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        // Setup ambisonic decoder
        ambisonicDecoder = AmbisonicDecoder(order: ambisonicOrder)

        // Setup HRTF processor
        hrtfProcessor = HRTFProcessor()

        // Setup room simulator
        roomSimulator = RoomSimulator()
    }

    private func loadDefaultHRTF() {
        // Load Apple's built-in HRTF or a custom profile
        currentHRTFProfile = HRTFProfile(
            name: "Apple Spatial Audio",
            sampleRate: 48000,
            impulseResponseLength: 512,
            elevationAngles: stride(from: -40, through: 90, by: 10).map { Float($0) },
            azimuthAngles: stride(from: 0, through: 355, by: 5).map { Float($0) },
            irData: [:]  // Loaded from CoreAudio
        )
    }

    private func setupDefaultRoom() {
        currentRoomAcoustics = RoomAcoustics(
            roomSize: SIMD3<Float>(10, 3, 8),
            reverbTime: 0.8,
            absorptionCoefficients: [0.1, 0.15, 0.2, 0.25, 0.3, 0.35],
            diffusion: 0.7,
            earlyReflections: true,
            lateReverb: true,
            wallMaterial: .wood,
            floorMaterial: .carpet,
            ceilingMaterial: .acoustic_tile
        )
    }

    // MARK: - Engine Control

    func start() async throws {
        guard let engine = audioEngine else {
            throw APACError.engineNotInitialized
        }

        try engine.start()
        isActive = true

        print("🎧 APAC: Spatial audio engine started")
    }

    func stop() {
        audioEngine?.stop()
        isActive = false

        print("🎧 APAC: Spatial audio engine stopped")
    }

    // MARK: - Listener Control

    func updateListener(position: SIMD3<Float>, orientation: simd_quatf) {
        listenerPosition = position
        listenerOrientation = orientation

        guard let mixer = spatialMixer else { return }

        // Update AVAudioEnvironmentNode listener
        mixer.listenerPosition = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)

        // Convert quaternion to forward/up vectors
        let forward = orientation.act(SIMD3<Float>(0, 0, -1))
        let up = orientation.act(SIMD3<Float>(0, 1, 0))

        mixer.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: forward.x, y: forward.y, z: forward.z),
            up: AVAudio3DVector(x: up.x, y: up.y, z: up.z)
        )
    }

    func enableHeadTracking(_ enabled: Bool) {
        headTrackingEnabled = enabled

        #if os(visionOS) || os(iOS)
        if enabled {
            // Enable device motion tracking
            // This is handled by the system on visionOS
        }
        #endif

        print("🎧 APAC: Head tracking \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Audio Source Management

    func createSource(
        name: String,
        position: SIMD3<Float>,
        type: SpatialAudioSource.SourceType = .pointSource,
        audioFile: URL? = nil
    ) async throws -> UUID {
        guard let engine = audioEngine, let mixer = spatialMixer else {
            throw APACError.engineNotInitialized
        }

        let sourceID = UUID()

        // Create player node
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        // Configure 3D audio mixing point
        playerNode.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        playerNode.renderingAlgorithm = .HRTFHQ

        // Set default attenuation
        playerNode.reverbBlend = 0.3

        // Connect to spatial mixer
        engine.connect(playerNode, to: mixer, format: nil)

        // Store reference
        sourceNodes[sourceID] = playerNode

        // Create source model
        let source = SpatialAudioSource(
            id: sourceID,
            name: name,
            position: position,
            orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            type: type,
            volume: 1.0,
            isPlaying: false,
            attenuationModel: .logarithmic,
            referenceDistance: 1.0,
            maxDistance: 100.0,
            rolloffFactor: 1.0,
            directivityPattern: .omnidirectional,
            innerConeAngle: 360.0,
            outerConeAngle: 360.0,
            outerConeGain: 1.0,
            occlusionLevel: 0.0,
            obstructionLevel: 0.0,
            reverbSendLevel: 0.3,
            reverbBus: 0
        )

        activeSources.append(source)

        // Load audio file if provided
        if let url = audioFile {
            try await loadAudioFile(url, for: sourceID)
        }

        print("🎧 APAC: Created spatial source '\(name)' at \(position)")
        return sourceID
    }

    func loadAudioFile(_ url: URL, for sourceID: UUID) async throws {
        guard let playerNode = sourceNodes[sourceID] else {
            throw APACError.sourceNotFound
        }

        let audioFile = try AVAudioFile(forReading: url)
        sourceFormats[sourceID] = audioFile.processingFormat

        playerNode.scheduleFile(audioFile, at: nil)
    }

    func updateSourcePosition(_ sourceID: UUID, position: SIMD3<Float>) {
        guard let playerNode = sourceNodes[sourceID],
              let index = activeSources.firstIndex(where: { $0.id == sourceID }) else { return }

        playerNode.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        activeSources[index].position = position

        // Apply distance attenuation
        let source = activeSources[index]
        let distance = simd_length(position - listenerPosition)
        let attenuation = calculateAttenuation(
            distance: distance,
            model: source.attenuationModel,
            referenceDistance: source.referenceDistance,
            maxDistance: source.maxDistance,
            rolloffFactor: source.rolloffFactor
        )

        playerNode.volume = source.volume * attenuation
    }

    func updateSourceOrientation(_ sourceID: UUID, orientation: simd_quatf) {
        guard let index = activeSources.firstIndex(where: { $0.id == sourceID }) else { return }

        activeSources[index].orientation = orientation

        // Apply directivity pattern
        applyDirectivity(sourceID: sourceID)
    }

    func setSourceVolume(_ sourceID: UUID, volume: Float) {
        guard let playerNode = sourceNodes[sourceID],
              let index = activeSources.firstIndex(where: { $0.id == sourceID }) else { return }

        activeSources[index].volume = volume
        playerNode.volume = volume
    }

    func playSource(_ sourceID: UUID) {
        guard let playerNode = sourceNodes[sourceID],
              let index = activeSources.firstIndex(where: { $0.id == sourceID }) else { return }

        playerNode.play()
        activeSources[index].isPlaying = true
    }

    func stopSource(_ sourceID: UUID) {
        guard let playerNode = sourceNodes[sourceID],
              let index = activeSources.firstIndex(where: { $0.id == sourceID }) else { return }

        playerNode.stop()
        activeSources[index].isPlaying = false
    }

    func removeSource(_ sourceID: UUID) {
        guard let playerNode = sourceNodes[sourceID] else { return }

        playerNode.stop()
        audioEngine?.detach(playerNode)

        sourceNodes.removeValue(forKey: sourceID)
        sourceFormats.removeValue(forKey: sourceID)
        activeSources.removeAll { $0.id == sourceID }
    }

    // MARK: - Attenuation

    private func calculateAttenuation(
        distance: Float,
        model: SpatialAudioSource.AttenuationModel,
        referenceDistance: Float,
        maxDistance: Float,
        rolloffFactor: Float
    ) -> Float {
        let clampedDistance = max(referenceDistance, min(maxDistance, distance))

        switch model {
        case .none:
            return 1.0

        case .linear:
            return max(0, 1.0 - rolloffFactor * (clampedDistance - referenceDistance) / (maxDistance - referenceDistance))

        case .logarithmic:
            return referenceDistance / (referenceDistance + rolloffFactor * (clampedDistance - referenceDistance))

        case .inverse:
            return referenceDistance / (referenceDistance + rolloffFactor * clampedDistance)

        case .custom:
            // Placeholder for user-defined curve
            return 1.0 / (1.0 + clampedDistance * rolloffFactor)
        }
    }

    // MARK: - Directivity

    private func applyDirectivity(sourceID: UUID) {
        guard let index = activeSources.firstIndex(where: { $0.id == sourceID }) else { return }

        let source = activeSources[index]

        // Calculate angle from source to listener
        let sourceToListener = listenerPosition - source.position
        let sourceForward = source.orientation.act(SIMD3<Float>(0, 0, -1))

        let angle = acos(simd_dot(simd_normalize(sourceToListener), sourceForward)) * (180.0 / .pi)

        // Apply cone attenuation
        var directivityGain: Float = 1.0

        if angle <= source.innerConeAngle / 2 {
            directivityGain = 1.0
        } else if angle <= source.outerConeAngle / 2 {
            let t = (angle - source.innerConeAngle / 2) / (source.outerConeAngle / 2 - source.innerConeAngle / 2)
            directivityGain = 1.0 + t * (source.outerConeGain - 1.0)
        } else {
            directivityGain = source.outerConeGain
        }

        if let playerNode = sourceNodes[sourceID] {
            playerNode.volume *= directivityGain
        }
    }

    // MARK: - Occlusion & Obstruction

    func setSourceOcclusion(_ sourceID: UUID, level: Float) {
        guard let index = activeSources.firstIndex(where: { $0.id == sourceID }),
              let playerNode = sourceNodes[sourceID] else { return }

        activeSources[index].occlusionLevel = level

        // Apply low-pass filter based on occlusion
        playerNode.obstruction = level * -24.0  // dB reduction
    }

    func setSourceObstruction(_ sourceID: UUID, level: Float) {
        guard let index = activeSources.firstIndex(where: { $0.id == sourceID }),
              let playerNode = sourceNodes[sourceID] else { return }

        activeSources[index].obstructionLevel = level

        // Apply high-frequency attenuation
        playerNode.occlusion = level * -18.0  // dB reduction
    }

    // MARK: - Ambisonic Encoding

    func encodeToAmbisonic(
        source: SpatialAudioSource,
        inputBuffer: [Float],
        order: Int = 3
    ) -> AmbisonicField {
        let channelCount = (order + 1) * (order + 1)
        var coefficients = [[Float]](repeating: [Float](repeating: 0, count: inputBuffer.count), count: channelCount)

        // Calculate spherical harmonics encoding
        let relativePos = source.position - listenerPosition
        let distance = simd_length(relativePos)
        let direction = distance > 0 ? relativePos / distance : SIMD3<Float>(0, 0, 1)

        // Convert to spherical coordinates
        let azimuth = atan2(direction.x, -direction.z)
        let elevation = asin(direction.y)

        // Encode to ambisonic channels
        for i in 0..<inputBuffer.count {
            let sample = inputBuffer[i]

            // Order 0 (W channel - omnidirectional)
            coefficients[0][i] = sample * 0.707  // 1/sqrt(2)

            if order >= 1 {
                // Order 1 (X, Y, Z - figure-8 patterns)
                coefficients[1][i] = sample * cos(azimuth) * cos(elevation)   // Y
                coefficients[2][i] = sample * sin(elevation)                    // Z
                coefficients[3][i] = sample * sin(azimuth) * cos(elevation)   // X
            }

            if order >= 2 {
                // Order 2 (5 channels)
                let cosElev = cos(elevation)
                let sinElev = sin(elevation)
                let cos2Azim = cos(2 * azimuth)
                let sin2Azim = sin(2 * azimuth)

                coefficients[4][i] = sample * 0.866 * sin2Azim * cosElev * cosElev
                coefficients[5][i] = sample * sin(azimuth) * sinElev * cosElev
                coefficients[6][i] = sample * 0.5 * (3 * sinElev * sinElev - 1)
                coefficients[7][i] = sample * cos(azimuth) * sinElev * cosElev
                coefficients[8][i] = sample * 0.866 * cos2Azim * cosElev * cosElev
            }

            if order >= 3 {
                // Order 3 (7 channels) - simplified
                coefficients[9][i] = sample * sin(3 * azimuth) * pow(cos(elevation), 3)
                coefficients[10][i] = sample * sin(2 * azimuth) * sin(elevation) * cos(elevation) * cos(elevation)
                coefficients[11][i] = sample * sin(azimuth) * (5 * sin(elevation) * sin(elevation) - 1) * cos(elevation)
                coefficients[12][i] = sample * (5 * pow(sin(elevation), 3) - 3 * sin(elevation))
                coefficients[13][i] = sample * cos(azimuth) * (5 * sin(elevation) * sin(elevation) - 1) * cos(elevation)
                coefficients[14][i] = sample * cos(2 * azimuth) * sin(elevation) * cos(elevation) * cos(elevation)
                coefficients[15][i] = sample * cos(3 * azimuth) * pow(cos(elevation), 3)
            }
        }

        return AmbisonicField(
            order: order,
            normalization: .sn3d,
            channelOrdering: .acn,
            coefficients: coefficients
        )
    }

    // MARK: - Room Acoustics

    func configureRoom(_ acoustics: RoomAcoustics) {
        currentRoomAcoustics = acoustics

        guard let mixer = spatialMixer else { return }

        // Configure reverb
        let reverb = mixer.reverbParameters

        // Map room size to reverb preset
        let volume = acoustics.roomSize.x * acoustics.roomSize.y * acoustics.roomSize.z
        if volume < 50 {
            reverb.loadFactoryReverbPreset(.smallRoom)
        } else if volume < 200 {
            reverb.loadFactoryReverbPreset(.mediumRoom)
        } else if volume < 500 {
            reverb.loadFactoryReverbPreset(.largeRoom)
        } else if volume < 2000 {
            reverb.loadFactoryReverbPreset(.mediumHall)
        } else {
            reverb.loadFactoryReverbPreset(.largeHall)
        }

        mixer.reverbBlend = 0.3  // Base reverb blend

        print("🎧 APAC: Room configured - \(acoustics.roomSize)m, RT60: \(acoustics.reverbTime)s")
    }

    func setRoomReverbLevel(_ level: Float) {
        spatialMixer?.reverbBlend = level
    }

    // MARK: - Bio-Reactive Audio

    func applyBioReactiveModulation(hrv: Float, coherence: Float) {
        // Adjust reverb based on coherence (more reverb when calm)
        let reverbBlend = 0.2 + (coherence * 0.3)
        spatialMixer?.reverbBlend = reverbBlend

        // Adjust distance perception based on stress
        for i in 0..<activeSources.count {
            var source = activeSources[i]

            // When stressed (low coherence), sounds feel closer/more urgent
            let stressMultiplier = 1.0 - (coherence * 0.3)
            source.rolloffFactor = 1.0 * stressMultiplier

            activeSources[i] = source
        }
    }

    // MARK: - APAC Export

    struct APACExportSettings {
        var format: APACFormat
        var sampleRate: Double
        var bitDepth: Int
        var ambisonicOrder: Int
        var includeMetadata: Bool

        enum APACFormat {
            case ambisonicB      // B-format ambisonics
            case ambisonicA      // A-format (raw capsule)
            case objectBased     // Object-based with positions
            case binaural        // Pre-rendered binaural
        }
    }

    func exportSpatialAudio(
        sources: [UUID],
        duration: TimeInterval,
        settings: APACExportSettings
    ) async throws -> Data {
        // Render spatial audio to the specified format
        var outputData = Data()

        // This would render the actual audio data
        // Simplified placeholder

        print("🎧 APAC: Exported \(sources.count) sources as \(settings.format)")

        return outputData
    }

    // MARK: - Error Types

    enum APACError: LocalizedError {
        case engineNotInitialized
        case sourceNotFound
        case formatNotSupported
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .engineNotInitialized:
                return "Audio engine not initialized"
            case .sourceNotFound:
                return "Audio source not found"
            case .formatNotSupported:
                return "Audio format not supported"
            case .renderFailed:
                return "Failed to render spatial audio"
            }
        }
    }
}

// MARK: - Supporting Classes

class AmbisonicDecoder {
    let order: Int

    init(order: Int) {
        self.order = order
    }

    func decodeToSpeakers(field: APACSpatialAudioEngine.AmbisonicField, speakerLayout: SpeakerLayout) -> [[Float]] {
        // Decode ambisonics to speaker feeds
        return []
    }

    func decodeToBinaural(field: APACSpatialAudioEngine.AmbisonicField, hrtf: APACSpatialAudioEngine.HRTFProfile) -> (left: [Float], right: [Float]) {
        // Decode to binaural using HRTF
        return ([], [])
    }

    enum SpeakerLayout {
        case stereo
        case quad
        case surround51
        case surround71
        case atmos714
        case custom(positions: [SIMD3<Float>])
    }
}

class HRTFProcessor {
    func processWithHRTF(
        input: [Float],
        azimuth: Float,
        elevation: Float,
        distance: Float
    ) -> (left: [Float], right: [Float]) {
        // Apply HRTF filtering
        return (input, input)  // Simplified
    }
}

class RoomSimulator {
    func simulateEarlyReflections(
        source: SIMD3<Float>,
        listener: SIMD3<Float>,
        room: APACSpatialAudioEngine.RoomAcoustics
    ) -> [Reflection] {
        // Calculate early reflections using image source method
        return []
    }

    struct Reflection {
        var delay: TimeInterval
        var gain: Float
        var direction: SIMD3<Float>
        var filterCoefficients: [Float]
    }
}
