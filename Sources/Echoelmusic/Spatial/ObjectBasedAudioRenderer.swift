import Foundation
import Combine
import simd

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Object-based spatial audio renderer supporting Dolby Atmos-style workflows.
///
/// Manages audio objects in 3D space with:
/// - Dynamic bed channels (channel-based surround beds)
/// - Audio objects with 3D position, size, and movement
/// - Apple Spatial Audio integration via AVAudioEnvironmentNode
/// - Bio-reactive spatial positioning based on HRV coherence
///
/// Architecture:
/// ```
/// Audio Objects → Position/Metadata → AVAudioEnvironmentNode (Apple Spatial Audio)
///                                   → AmbisonicsProcessor (custom HOA)
///                                   → Binaural output via HRTFProcessor
/// ```
class ObjectBasedAudioRenderer {

    // MARK: - Types

    enum RenderMode: String, CaseIterable {
        case appleSpatialized    // AVAudioEnvironmentNode with Apple Spatial Audio
        case ambisonics          // Custom HOA via AmbisonicsProcessor
        case binaural            // Custom HRTF processing
        case channelBed          // Traditional channel-based (7.1.4 etc.)
    }

    enum BedFormat: String, CaseIterable {
        case stereo              // 2.0
        case surround5_1        // 5.1
        case surround7_1        // 7.1
        case atmos7_1_4         // 7.1.4 (with height channels)

        var channelCount: Int {
            switch self {
            case .stereo: return 2
            case .surround5_1: return 6
            case .surround7_1: return 8
            case .atmos7_1_4: return 12
            }
        }
    }

    struct AudioObject: Identifiable {
        let id: UUID
        var name: String
        var position: SIMD3<Float>           // 3D position in meters
        var size: Float = 0.0                // Object size (0 = point source, 1 = ambient)
        var gain: Float = 1.0                // Volume (0-1)
        var priority: Int = 0                // Rendering priority (higher = more important)
        var spread: Float = 0.0              // Angular spread (0 = point, 1 = omnidirectional)
        var isStatic: Bool = false           // Static objects can use cached rendering
        var bedAssignment: BedFormat?        // If assigned to a bed channel
        var automationPath: AutomationPath?  // Movement automation
    }

    struct AutomationPath {
        var keyframes: [(time: Double, position: SIMD3<Float>)]
        var interpolation: InterpolationType = .smooth
        var isLooping: Bool = false

        enum InterpolationType {
            case linear
            case smooth    // Catmull-Rom spline
            case step
        }

        /// Get interpolated position at given time.
        func positionAt(time: Double) -> SIMD3<Float> {
            guard keyframes.count >= 2 else {
                return keyframes.first?.position ?? .zero
            }

            var effectiveTime = time
            if isLooping, let first = keyframes.first, let last = keyframes.last {
                let duration = last.time - first.time
                if duration > 0 {
                    effectiveTime = first.time + fmod(time - first.time, duration)
                }
            }

            // Find surrounding keyframes
            var prevIdx = 0
            for (i, kf) in keyframes.enumerated() {
                if kf.time <= effectiveTime { prevIdx = i }
            }
            let nextIdx = min(prevIdx + 1, keyframes.count - 1)

            if prevIdx == nextIdx { return keyframes[prevIdx].position }

            let prevKF = keyframes[prevIdx]
            let nextKF = keyframes[nextIdx]
            let t = Float((effectiveTime - prevKF.time) / (nextKF.time - prevKF.time))

            switch interpolation {
            case .linear:
                return simd_mix(prevKF.position, nextKF.position, SIMD3<Float>(repeating: t))
            case .smooth:
                let smoothT = t * t * (3.0 - 2.0 * t) // Hermite smoothstep
                return simd_mix(prevKF.position, nextKF.position, SIMD3<Float>(repeating: smoothT))
            case .step:
                return prevKF.position
            }
        }
    }

    struct Configuration {
        var renderMode: RenderMode = .appleSpatialized
        var bedFormat: BedFormat = .atmos7_1_4
        var maxObjects: Int = 128            // Dolby Atmos supports 128 objects
        var headTrackingEnabled: Bool = true
        var bioReactivePositioning: Bool = true
        var distanceAttenuationModel: DistanceModel = .inverseSquare

        static let `default` = Configuration()
        static let performance = Configuration(renderMode: .appleSpatialized, maxObjects: 32)
        static let highQuality = Configuration(renderMode: .ambisonics, maxObjects: 128)
    }

    enum DistanceModel {
        case linear(referenceDistance: Float, maxDistance: Float)
        case inverseSquare
        case exponential(rolloffFactor: Float)

        func attenuation(distance: Float) -> Float {
            switch self {
            case .linear(let ref, let maxDist):
                let clamped = min(max(distance, ref), maxDist)
                return 1.0 - (clamped - ref) / (maxDist - ref)
            case .inverseSquare:
                let d = max(distance, 0.1)
                return 1.0 / (d * d)
            case .exponential(let rolloff):
                return powf(max(distance, 0.1), -rolloff)
            }
        }
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double

    /// Active audio objects
    private(set) var objects: [UUID: AudioObject] = [:]

    /// Bed channel layout
    private(set) var bedChannels: [Float] = []

    #if canImport(AVFoundation)
    /// Apple Audio Engine components
    private var audioEngine: AVAudioEngine?
    private var environmentNode: AVAudioEnvironmentNode?
    private var objectPlayerNodes: [UUID: AVAudioPlayerNode] = [:]
    #endif

    /// Custom processor fallbacks
    private var ambisonicsProcessor: AmbisonicsProcessor?
    private var dopplerProcessor: DopplerProcessor?

    /// Bio-reactive state
    private var coherence: Float = 0.5
    private var heartRate: Float = 70.0

    /// Animation time
    private var currentTime: Double = 0

    // MARK: - Initialization

    init(sampleRate: Double = 48000, configuration: Configuration = .default) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        self.bedChannels = [Float](repeating: 0, count: configuration.bedFormat.channelCount)

        setupRenderer()
    }

    private func setupRenderer() {
        switch configuration.renderMode {
        case .appleSpatialized:
            setupAppleSpatialAudio()
        case .ambisonics:
            ambisonicsProcessor = AmbisonicsProcessor(
                sampleRate: sampleRate,
                configuration: .highQuality
            )
        case .binaural, .channelBed:
            break
        }

        dopplerProcessor = DopplerProcessor(sampleRate: sampleRate)
    }

    // MARK: - Apple Spatial Audio Setup

    private func setupAppleSpatialAudio() {
        #if canImport(AVFoundation) && !os(watchOS)
        audioEngine = AVAudioEngine()
        environmentNode = AVAudioEnvironmentNode()

        guard let engine = audioEngine, let envNode = environmentNode else { return }

        engine.attach(envNode)
        engine.connect(envNode, to: engine.mainMixerNode, format: nil)

        // Configure environment for object-based rendering
        envNode.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        envNode.distanceAttenuationParameters.referenceDistance = 1.0
        envNode.distanceAttenuationParameters.maximumDistance = 100.0
        envNode.distanceAttenuationParameters.rolloffFactor = 1.0

        // Enable reverb for room simulation
        envNode.reverbParameters.enable = true
        envNode.reverbParameters.level = -10.0 // dB
        envNode.reverbParameters.loadFactoryReverbPreset(.mediumHall)

        // Set rendering algorithm for spatial audio
        envNode.renderingAlgorithm = .HRTFHQ
        #endif
    }

    // MARK: - Object Management

    /// Add an audio object to the renderer.
    @discardableResult
    func addObject(
        name: String,
        position: SIMD3<Float>,
        size: Float = 0.0,
        gain: Float = 1.0,
        priority: Int = 0
    ) -> UUID {
        let id = UUID()
        var obj = AudioObject(id: id, name: name, position: position)
        obj.size = size
        obj.gain = gain
        obj.priority = priority

        objects[id] = obj

        #if canImport(AVFoundation) && !os(watchOS)
        if configuration.renderMode == .appleSpatialized {
            createAppleAudioNode(for: id, position: position)
        }
        #endif

        return id
    }

    /// Remove an audio object.
    func removeObject(_ id: UUID) {
        objects.removeValue(forKey: id)
        dopplerProcessor?.removeSource(id)

        #if canImport(AVFoundation) && !os(watchOS)
        if let node = objectPlayerNodes.removeValue(forKey: id) {
            node.stop()
            audioEngine?.detach(node)
        }
        #endif
    }

    /// Update an object's 3D position.
    func updateObjectPosition(_ id: UUID, position: SIMD3<Float>) {
        guard var obj = objects[id] else { return }
        let previousPosition = obj.position
        obj.position = position
        objects[id] = obj

        // Compute velocity for Doppler processing
        let velocity = position - previousPosition // Approximate (assumes 1 frame interval)

        #if canImport(AVFoundation) && !os(watchOS)
        if let node = objectPlayerNodes[id], let envNode = environmentNode {
            // Apply position to Apple spatial audio node
            node.position = AVAudio3DPoint(
                x: Float(position.x),
                y: Float(position.y),
                z: Float(position.z)
            )
        }
        #endif
    }

    /// Update object's gain.
    func updateObjectGain(_ id: UUID, gain: Float) {
        objects[id]?.gain = max(0, min(1, gain))

        #if canImport(AVFoundation) && !os(watchOS)
        objectPlayerNodes[id]?.volume = gain
        #endif
    }

    /// Set an automation path for object movement.
    func setObjectAutomation(_ id: UUID, path: AutomationPath) {
        objects[id]?.automationPath = path
    }

    // MARK: - Bio-Reactive Integration

    /// Update bio-reactive state for spatial positioning.
    func updateBioState(coherence: Float, heartRate: Float) {
        self.coherence = coherence
        self.heartRate = heartRate

        guard configuration.bioReactivePositioning else { return }

        // Bio-reactive spatial modifications:
        // High coherence → objects settle into harmonic positions
        // Low coherence → objects drift/scatter

        for (id, var obj) in objects {
            guard !obj.isStatic else { continue }

            // Modulate spread based on coherence (high coherence = tighter)
            let baseSpread = obj.spread
            obj.spread = baseSpread * (1.5 - coherence)

            // Subtle position modulation synced to heart rate
            let pulse = sin(Float(currentTime) * heartRate / 60.0 * 2.0 * .pi)
            let pulseOffset = SIMD3<Float>(0, pulse * 0.02 * coherence, 0)
            let modulatedPosition = obj.position + pulseOffset

            objects[id] = obj

            #if canImport(AVFoundation) && !os(watchOS)
            if let node = objectPlayerNodes[id] {
                node.position = AVAudio3DPoint(
                    x: modulatedPosition.x,
                    y: modulatedPosition.y,
                    z: modulatedPosition.z
                )
            }
            #endif
        }
    }

    // MARK: - Animation Update

    /// Advance animation time and update automated object positions.
    func update(deltaTime: Double) {
        currentTime += deltaTime

        for (id, obj) in objects {
            guard let path = obj.automationPath else { continue }
            let newPos = path.positionAt(time: currentTime)
            updateObjectPosition(id, position: newPos)
        }
    }

    // MARK: - Rendering

    /// Render all objects to a stereo buffer (custom processing path).
    func renderToStereo(bufferSize: Int) -> (left: [Float], right: [Float]) {
        guard let ambiProcessor = ambisonicsProcessor else {
            return ([Float](repeating: 0, count: bufferSize),
                    [Float](repeating: 0, count: bufferSize))
        }

        ambiProcessor.clearAccumulator()

        // Encode each object into ambisonics
        for obj in objects.values where obj.gain > 0.001 {
            let dist = simd_length(obj.position)
            guard dist > 0.001 else { continue }

            let azimuth = atan2(obj.position.y, obj.position.x) * 180.0 / .pi
            let elevation = asin(obj.position.z / dist) * 180.0 / .pi

            // Generate silence placeholder (actual audio would come from player nodes)
            let silence = [Float](repeating: 0, count: bufferSize)

            ambiProcessor.accumulateSource(
                silence,
                azimuth: azimuth,
                elevation: elevation,
                distance: dist
            )
        }

        return ambiProcessor.decodeToStereo(ambiProcessor.decodeAccumulated().isEmpty ? [[]] : [])
    }

    // MARK: - Apple Audio Node Helpers

    #if canImport(AVFoundation) && !os(watchOS)
    private func createAppleAudioNode(for id: UUID, position: SIMD3<Float>) {
        guard let engine = audioEngine, let envNode = environmentNode else { return }

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: envNode, format: nil)

        playerNode.position = AVAudio3DPoint(
            x: position.x,
            y: position.y,
            z: position.z
        )
        playerNode.renderingAlgorithm = .HRTFHQ

        objectPlayerNodes[id] = playerNode
    }
    #endif

    // MARK: - Start / Stop

    func start() throws {
        #if canImport(AVFoundation) && !os(watchOS)
        try audioEngine?.start()
        #endif
    }

    func stop() {
        #if canImport(AVFoundation) && !os(watchOS)
        audioEngine?.stop()
        #endif
    }

    // MARK: - Query

    /// Get all objects sorted by priority.
    var objectsByPriority: [AudioObject] {
        objects.values.sorted { $0.priority > $1.priority }
    }

    /// Active object count.
    var activeObjectCount: Int { objects.count }

    // MARK: - Reset

    func reset() {
        for id in objects.keys {
            removeObject(id)
        }
        objects.removeAll()
        dopplerProcessor?.reset()
        ambisonicsProcessor?.reset()
        currentTime = 0
    }
}
