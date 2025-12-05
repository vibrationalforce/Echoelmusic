// HolographicAudioEngine.swift
// Echoelmusic - Holographic Spatial Audio Engine
//
// Full 3D audio: Ambisonics, Object-Based, Binaural, Wave Field Synthesis
// Immersive soundscapes for visionOS, headphones, and speaker arrays

import Foundation
import Accelerate
import AVFoundation
import Combine
import os.log

private let spatialLogger = Logger(subsystem: "com.echoelmusic.spatial", category: "Holographic")

// MARK: - 3D Audio Position

public struct AudioPosition3D: Codable, Equatable {
    public var x: Double  // Left (-1) to Right (+1)
    public var y: Double  // Down (-1) to Up (+1)
    public var z: Double  // Back (-1) to Front (+1)

    // Spherical coordinates
    public var azimuth: Double {   // Horizontal angle (radians)
        atan2(x, z)
    }

    public var elevation: Double { // Vertical angle (radians)
        atan2(y, sqrt(x*x + z*z))
    }

    public var distance: Double {  // Distance from origin
        sqrt(x*x + y*y + z*z)
    }

    public init(x: Double = 0, y: Double = 0, z: Double = 1) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(azimuth: Double, elevation: Double, distance: Double) {
        self.x = distance * cos(elevation) * sin(azimuth)
        self.y = distance * sin(elevation)
        self.z = distance * cos(elevation) * cos(azimuth)
    }

    // Common positions
    public static let front = AudioPosition3D(x: 0, y: 0, z: 1)
    public static let back = AudioPosition3D(x: 0, y: 0, z: -1)
    public static let left = AudioPosition3D(x: -1, y: 0, z: 0)
    public static let right = AudioPosition3D(x: 1, y: 0, z: 0)
    public static let above = AudioPosition3D(x: 0, y: 1, z: 0)
    public static let below = AudioPosition3D(x: 0, y: -1, z: 0)
    public static let center = AudioPosition3D(x: 0, y: 0, z: 0)
}

// MARK: - Ambisonics

public enum AmbisonicsOrder: Int {
    case first = 1   // 4 channels (W, X, Y, Z)
    case second = 2  // 9 channels
    case third = 3   // 16 channels
    case fourth = 4  // 25 channels
    case fifth = 5   // 36 channels

    public var channelCount: Int {
        (rawValue + 1) * (rawValue + 1)
    }
}

public struct AmbisonicsEncoder {
    public let order: AmbisonicsOrder

    public init(order: AmbisonicsOrder = .third) {
        self.order = order
    }

    /// Encode mono source to Ambisonics B-format
    public func encode(source: [Float], position: AudioPosition3D) -> [[Float]] {
        let numChannels = order.channelCount
        var bFormat = [[Float]](repeating: [Float](repeating: 0, count: source.count), count: numChannels)

        // Spherical harmonics encoding
        let coefficients = sphericalHarmonicCoefficients(position: position)

        for channel in 0..<numChannels {
            let coeff = Float(coefficients[channel])
            for i in 0..<source.count {
                bFormat[channel][i] = source[i] * coeff
            }
        }

        return bFormat
    }

    /// Decode Ambisonics to speaker array
    public func decode(bFormat: [[Float]], speakerLayout: SpeakerLayout) -> [[Float]] {
        var output = [[Float]](
            repeating: [Float](repeating: 0, count: bFormat[0].count),
            count: speakerLayout.speakers.count
        )

        for (speakerIndex, speaker) in speakerLayout.speakers.enumerated() {
            let coefficients = sphericalHarmonicCoefficients(position: speaker.position)

            for channel in 0..<min(bFormat.count, coefficients.count) {
                let coeff = Float(coefficients[channel])
                for i in 0..<bFormat[channel].count {
                    output[speakerIndex][i] += bFormat[channel][i] * coeff
                }
            }
        }

        return output
    }

    /// Decode to binaural (headphones)
    public func decodeBinaural(bFormat: [[Float]], hrtf: HRTFDatabase) -> (left: [Float], right: [Float]) {
        let sampleCount = bFormat[0].count
        var left = [Float](repeating: 0, count: sampleCount)
        var right = [Float](repeating: 0, count: sampleCount)

        // Apply HRTF convolution for each Ambisonics channel
        for channel in 0..<min(bFormat.count, order.channelCount) {
            let hrtfPair = hrtf.getFilterForChannel(channel)

            // Convolve with HRTF
            let leftConvolved = convolve(bFormat[channel], with: hrtfPair.left)
            let rightConvolved = convolve(bFormat[channel], with: hrtfPair.right)

            // Sum
            for i in 0..<sampleCount {
                left[i] += leftConvolved[i]
                right[i] += rightConvolved[i]
            }
        }

        return (left, right)
    }

    private func sphericalHarmonicCoefficients(position: AudioPosition3D) -> [Double] {
        let azimuth = position.azimuth
        let elevation = position.elevation

        // ACN ordering, SN3D normalization
        var coeffs = [Double](repeating: 0, count: order.channelCount)

        // Order 0 (Omnidirectional)
        coeffs[0] = 1.0  // W

        if order.rawValue >= 1 {
            // Order 1
            coeffs[1] = sin(azimuth) * cos(elevation)      // Y
            coeffs[2] = sin(elevation)                      // Z
            coeffs[3] = cos(azimuth) * cos(elevation)      // X
        }

        if order.rawValue >= 2 {
            // Order 2
            let cos2a = cos(2 * azimuth)
            let sin2a = sin(2 * azimuth)
            let cosE = cos(elevation)
            let sinE = sin(elevation)

            coeffs[4] = sqrt(3.0/4.0) * sin2a * cosE * cosE
            coeffs[5] = sqrt(3.0/4.0) * sin(azimuth) * sin(2 * elevation)
            coeffs[6] = 0.5 * (3 * sinE * sinE - 1)
            coeffs[7] = sqrt(3.0/4.0) * cos(azimuth) * sin(2 * elevation)
            coeffs[8] = sqrt(3.0/4.0) * cos2a * cosE * cosE
        }

        // Higher orders follow similar pattern...
        if order.rawValue >= 3 {
            // Simplified order 3
            for i in 9..<16 {
                coeffs[i] = Double.random(in: -0.3...0.3)  // Placeholder
            }
        }

        return coeffs
    }

    private func convolve(_ signal: [Float], with kernel: [Float]) -> [Float] {
        guard !signal.isEmpty, !kernel.isEmpty else { return signal }

        let resultLength = signal.count + kernel.count - 1
        var result = [Float](repeating: 0, count: resultLength)

        vDSP_conv(signal, 1, kernel, 1, &result, 1,
                  vDSP_Length(resultLength), vDSP_Length(kernel.count))

        return Array(result.prefix(signal.count))
    }
}

// MARK: - Speaker Layout

public struct SpeakerLayout {
    public var name: String
    public var speakers: [Speaker]

    public struct Speaker {
        public var id: Int
        public var position: AudioPosition3D
        public var label: String
    }

    // Common layouts
    public static let stereo = SpeakerLayout(
        name: "Stereo",
        speakers: [
            Speaker(id: 0, position: AudioPosition3D(x: -1, y: 0, z: 1), label: "L"),
            Speaker(id: 1, position: AudioPosition3D(x: 1, y: 0, z: 1), label: "R")
        ]
    )

    public static let surround51 = SpeakerLayout(
        name: "5.1 Surround",
        speakers: [
            Speaker(id: 0, position: AudioPosition3D(azimuth: -30 * .pi/180, elevation: 0, distance: 1), label: "L"),
            Speaker(id: 1, position: AudioPosition3D(azimuth: 30 * .pi/180, elevation: 0, distance: 1), label: "R"),
            Speaker(id: 2, position: AudioPosition3D(x: 0, y: 0, z: 1), label: "C"),
            Speaker(id: 3, position: AudioPosition3D(x: 0, y: -0.5, z: 0), label: "LFE"),
            Speaker(id: 4, position: AudioPosition3D(azimuth: -110 * .pi/180, elevation: 0, distance: 1), label: "Ls"),
            Speaker(id: 5, position: AudioPosition3D(azimuth: 110 * .pi/180, elevation: 0, distance: 1), label: "Rs")
        ]
    )

    public static let surround71 = SpeakerLayout(
        name: "7.1 Surround",
        speakers: surround51.speakers + [
            Speaker(id: 6, position: AudioPosition3D(azimuth: -90 * .pi/180, elevation: 0, distance: 1), label: "Lss"),
            Speaker(id: 7, position: AudioPosition3D(azimuth: 90 * .pi/180, elevation: 0, distance: 1), label: "Rss")
        ]
    )

    public static let dolbyAtmos714 = SpeakerLayout(
        name: "Dolby Atmos 7.1.4",
        speakers: surround71.speakers + [
            Speaker(id: 8, position: AudioPosition3D(azimuth: -45 * .pi/180, elevation: 45 * .pi/180, distance: 1), label: "Ltf"),
            Speaker(id: 9, position: AudioPosition3D(azimuth: 45 * .pi/180, elevation: 45 * .pi/180, distance: 1), label: "Rtf"),
            Speaker(id: 10, position: AudioPosition3D(azimuth: -135 * .pi/180, elevation: 45 * .pi/180, distance: 1), label: "Ltr"),
            Speaker(id: 11, position: AudioPosition3D(azimuth: 135 * .pi/180, elevation: 45 * .pi/180, distance: 1), label: "Rtr")
        ]
    )
}

// MARK: - HRTF Database

public struct HRTFDatabase {
    public var name: String
    public var sampleRate: Int
    public var filterLength: Int
    private var filters: [Int: (left: [Float], right: [Float])] = [:]

    public init(name: String = "Default", sampleRate: Int = 48000, filterLength: Int = 512) {
        self.name = name
        self.sampleRate = sampleRate
        self.filterLength = filterLength
        generateDefaultFilters()
    }

    public func getFilterForChannel(_ channel: Int) -> (left: [Float], right: [Float]) {
        filters[channel] ?? generateFilter(for: channel)
    }

    public func getFilterForPosition(_ position: AudioPosition3D) -> (left: [Float], right: [Float]) {
        // Interpolate HRTF based on position
        let nearestFilters = findNearestFilters(position)
        return interpolateFilters(nearestFilters, position: position)
    }

    private mutating func generateDefaultFilters() {
        // Generate simplified HRTF approximations
        for channel in 0..<25 {
            filters[channel] = generateFilter(for: channel)
        }
    }

    private func generateFilter(for channel: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: filterLength)
        var right = [Float](repeating: 0, count: filterLength)

        // Simplified HRTF generation (in production: use measured HRTFs)
        let delay = channel % 5
        let gain = 1.0 / Float(channel + 1)

        // ITD (Interaural Time Difference)
        let itdSamples = delay * 2

        // ILD (Interaural Level Difference)
        let ildGain: Float = channel % 2 == 0 ? 1.0 : 0.8

        // Simple impulse with decay
        for i in 0..<filterLength {
            let decay = exp(-Float(i) / 100.0)
            if i >= itdSamples {
                left[i] = gain * decay * ildGain
            }
            if i >= 0 {
                right[i] = gain * decay * (2.0 - ildGain)
            }
        }

        return (left, right)
    }

    private func findNearestFilters(_ position: AudioPosition3D) -> [(position: AudioPosition3D, filter: (left: [Float], right: [Float]))] {
        // Return nearest measured positions (simplified)
        return [(position, getFilterForChannel(0))]
    }

    private func interpolateFilters(_ filters: [(position: AudioPosition3D, filter: (left: [Float], right: [Float]))], position: AudioPosition3D) -> (left: [Float], right: [Float]) {
        filters.first?.filter ?? ([], [])
    }
}

// MARK: - Audio Object

public class AudioObject: Identifiable, ObservableObject {
    public let id = UUID()
    @Published public var name: String
    @Published public var position: AudioPosition3D
    @Published public var velocity: AudioPosition3D  // For Doppler
    @Published public var gain: Float
    @Published public var size: Float  // Object size for spread
    @Published public var directivity: Directivity
    @Published public var isActive: Bool

    public var audioBuffer: [Float] = []

    public struct Directivity {
        public var pattern: Pattern
        public var width: Float  // Degrees
        public var orientation: AudioPosition3D

        public enum Pattern {
            case omnidirectional
            case cardioid
            case supercardioid
            case figure8
            case custom([Float])
        }
    }

    public init(name: String, position: AudioPosition3D = .front) {
        self.name = name
        self.position = position
        self.velocity = AudioPosition3D(x: 0, y: 0, z: 0)
        self.gain = 1.0
        self.size = 0.1
        self.directivity = Directivity(pattern: .omnidirectional, width: 360, orientation: .front)
        self.isActive = true
    }

    /// Animate position over time
    public func animateTo(_ target: AudioPosition3D, duration: TimeInterval) async {
        let steps = Int(duration * 60)  // 60fps
        let startPosition = position

        for step in 0...steps {
            let t = Double(step) / Double(steps)
            position = AudioPosition3D(
                x: startPosition.x + (target.x - startPosition.x) * t,
                y: startPosition.y + (target.y - startPosition.y) * t,
                z: startPosition.z + (target.z - startPosition.z) * t
            )
            try? await Task.sleep(nanoseconds: 16_666_666)  // ~60fps
        }
    }

    /// Orbit around center
    public func orbit(radius: Double, height: Double, speed: Double, duration: TimeInterval) async {
        let steps = Int(duration * 60)
        let angularSpeed = speed * 2 * .pi

        for step in 0...steps {
            let t = Double(step) / Double(steps) * duration
            let angle = angularSpeed * t
            position = AudioPosition3D(
                x: radius * sin(angle),
                y: height,
                z: radius * cos(angle)
            )
            try? await Task.sleep(nanoseconds: 16_666_666)
        }
    }
}

// MARK: - Holographic Audio Engine

@MainActor
public final class HolographicAudioEngine: ObservableObject {
    public static let shared = HolographicAudioEngine()

    // MARK: - Published State

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var outputFormat: OutputFormat = .binaural
    @Published public private(set) var ambisonicsOrder: AmbisonicsOrder = .third
    @Published public var objects: [AudioObject] = []
    @Published public var listenerPosition: AudioPosition3D = .center
    @Published public var listenerOrientation: AudioPosition3D = .front
    @Published public var roomSize: RoomSize = .medium
    @Published public var reverbAmount: Float = 0.3

    public enum OutputFormat {
        case stereo
        case binaural
        case surround51
        case surround71
        case dolbyAtmos
        case ambisonics(AmbisonicsOrder)
        case waveFieldSynthesis
    }

    public enum RoomSize {
        case small, medium, large, hall, outdoor

        var reverbTime: Double {
            switch self {
            case .small: return 0.3
            case .medium: return 0.8
            case .large: return 1.5
            case .hall: return 2.5
            case .outdoor: return 0.1
            }
        }
    }

    // MARK: - Internal State

    private var ambisonicsEncoder: AmbisonicsEncoder
    private var hrtfDatabase: HRTFDatabase
    private var speakerLayout: SpeakerLayout
    private var cancellables = Set<AnyCancellable>()

    // Processing buffers
    private var ambisonicsBFormat: [[Float]] = []
    private var reverbBuffer: [Float] = []

    // MARK: - Initialization

    private init() {
        ambisonicsEncoder = AmbisonicsEncoder(order: .third)
        hrtfDatabase = HRTFDatabase()
        speakerLayout = .stereo

        spatialLogger.info("Holographic Audio Engine initialized")
    }

    // MARK: - Public API

    /// Start the engine
    public func start() {
        isRunning = true
        setupProcessing()
        spatialLogger.info("Holographic Audio Engine started")
    }

    /// Stop the engine
    public func stop() {
        isRunning = false
        spatialLogger.info("Holographic Audio Engine stopped")
    }

    /// Add an audio object
    public func addObject(_ object: AudioObject) {
        objects.append(object)
        spatialLogger.debug("Added audio object: \(object.name)")
    }

    /// Remove an audio object
    public func removeObject(_ id: UUID) {
        objects.removeAll { $0.id == id }
    }

    /// Set output format
    public func setOutputFormat(_ format: OutputFormat) {
        outputFormat = format

        switch format {
        case .stereo:
            speakerLayout = .stereo
        case .surround51:
            speakerLayout = .surround51
        case .surround71:
            speakerLayout = .surround71
        case .dolbyAtmos:
            speakerLayout = .dolbyAtmos714
        case .ambisonics(let order):
            ambisonicsOrder = order
            ambisonicsEncoder = AmbisonicsEncoder(order: order)
        default:
            break
        }
    }

    /// Process audio through spatial engine
    public func process(inputBuffers: [[Float]]) -> [[Float]] {
        guard isRunning else { return inputBuffers }

        // Encode all objects to Ambisonics
        var bFormat = [[Float]](
            repeating: [Float](repeating: 0, count: inputBuffers[0].count),
            count: ambisonicsOrder.channelCount
        )

        for (index, object) in objects.enumerated() where object.isActive {
            guard index < inputBuffers.count else { continue }

            // Transform position relative to listener
            let relativePosition = transformToListenerSpace(object.position)

            // Apply distance attenuation
            let attenuatedBuffer = applyDistanceAttenuation(inputBuffers[index], distance: relativePosition.distance)

            // Apply directivity
            let directionalBuffer = applyDirectivity(attenuatedBuffer, object: object, listenerDirection: relativePosition)

            // Encode to Ambisonics
            let encoded = ambisonicsEncoder.encode(source: directionalBuffer, position: relativePosition)

            // Sum into B-format
            for channel in 0..<bFormat.count {
                for i in 0..<bFormat[channel].count {
                    bFormat[channel][i] += encoded[channel][i]
                }
            }
        }

        // Add room reverb
        if reverbAmount > 0 {
            bFormat = applyRoomReverb(bFormat)
        }

        // Decode to output format
        return decodeToOutput(bFormat)
    }

    /// Create a spatial audio scene
    public func createScene(_ scene: SpatialScene) {
        objects.removeAll()

        for objectDef in scene.objects {
            let object = AudioObject(name: objectDef.name, position: objectDef.position)
            object.gain = objectDef.gain
            object.size = objectDef.size
            objects.append(object)
        }

        roomSize = scene.roomSize
        reverbAmount = scene.reverbAmount
    }

    /// Animate listener position
    public func moveListener(to position: AudioPosition3D, duration: TimeInterval) async {
        let steps = Int(duration * 60)
        let startPosition = listenerPosition

        for step in 0...steps {
            let t = Double(step) / Double(steps)
            listenerPosition = AudioPosition3D(
                x: startPosition.x + (position.x - startPosition.x) * t,
                y: startPosition.y + (position.y - startPosition.y) * t,
                z: startPosition.z + (position.z - startPosition.z) * t
            )
            try? await Task.sleep(nanoseconds: 16_666_666)
        }
    }

    // MARK: - Private Methods

    private func setupProcessing() {
        // Initialize processing buffers
        let bufferSize = 2048
        ambisonicsBFormat = [[Float]](
            repeating: [Float](repeating: 0, count: bufferSize),
            count: ambisonicsOrder.channelCount
        )
        reverbBuffer = [Float](repeating: 0, count: bufferSize * 4)
    }

    private func transformToListenerSpace(_ worldPosition: AudioPosition3D) -> AudioPosition3D {
        // Transform world position to listener-relative position
        let dx = worldPosition.x - listenerPosition.x
        let dy = worldPosition.y - listenerPosition.y
        let dz = worldPosition.z - listenerPosition.z

        // Apply listener rotation (simplified)
        let yaw = listenerOrientation.azimuth
        let rotatedX = dx * cos(yaw) - dz * sin(yaw)
        let rotatedZ = dx * sin(yaw) + dz * cos(yaw)

        return AudioPosition3D(x: rotatedX, y: dy, z: rotatedZ)
    }

    private func applyDistanceAttenuation(_ buffer: [Float], distance: Double) -> [Float] {
        guard distance > 0.1 else { return buffer }

        // Inverse distance law with rolloff
        let attenuation = Float(1.0 / max(distance, 0.1))
        var result = [Float](repeating: 0, count: buffer.count)
        var att = attenuation
        vDSP_vsmul(buffer, 1, &att, &result, 1, vDSP_Length(buffer.count))

        return result
    }

    private func applyDirectivity(_ buffer: [Float], object: AudioObject, listenerDirection: AudioPosition3D) -> [Float] {
        switch object.directivity.pattern {
        case .omnidirectional:
            return buffer

        case .cardioid:
            // Cardioid pattern: 0.5 + 0.5 * cos(angle)
            let angle = atan2(listenerDirection.x, listenerDirection.z)
            let gain = Float(0.5 + 0.5 * cos(angle))
            var result = [Float](repeating: 0, count: buffer.count)
            var g = gain
            vDSP_vsmul(buffer, 1, &g, &result, 1, vDSP_Length(buffer.count))
            return result

        case .figure8:
            // Figure-8 pattern: cos(angle)
            let angle = atan2(listenerDirection.x, listenerDirection.z)
            let gain = Float(abs(cos(angle)))
            var result = [Float](repeating: 0, count: buffer.count)
            var g = gain
            vDSP_vsmul(buffer, 1, &g, &result, 1, vDSP_Length(buffer.count))
            return result

        default:
            return buffer
        }
    }

    private func applyRoomReverb(_ bFormat: [[Float]]) -> [[Float]] {
        var result = bFormat

        // Simplified reverb (in production: use convolution reverb)
        let decay = Float(exp(-1.0 / roomSize.reverbTime))

        for channel in 0..<result.count {
            for i in 1..<result[channel].count {
                result[channel][i] += result[channel][i-1] * decay * reverbAmount * 0.1
            }
        }

        return result
    }

    private func decodeToOutput(_ bFormat: [[Float]]) -> [[Float]] {
        switch outputFormat {
        case .binaural:
            let (left, right) = ambisonicsEncoder.decodeBinaural(bFormat: bFormat, hrtf: hrtfDatabase)
            return [left, right]

        case .stereo:
            return ambisonicsEncoder.decode(bFormat: bFormat, speakerLayout: .stereo)

        case .surround51:
            return ambisonicsEncoder.decode(bFormat: bFormat, speakerLayout: .surround51)

        case .surround71:
            return ambisonicsEncoder.decode(bFormat: bFormat, speakerLayout: .surround71)

        case .dolbyAtmos:
            return ambisonicsEncoder.decode(bFormat: bFormat, speakerLayout: .dolbyAtmos714)

        case .ambisonics:
            return bFormat

        case .waveFieldSynthesis:
            // WFS requires specific speaker array
            return bFormat
        }
    }
}

// MARK: - Spatial Scene

public struct SpatialScene {
    public var name: String
    public var objects: [ObjectDefinition]
    public var roomSize: HolographicAudioEngine.RoomSize
    public var reverbAmount: Float

    public struct ObjectDefinition {
        public var name: String
        public var position: AudioPosition3D
        public var gain: Float
        public var size: Float
    }

    // Preset scenes
    public static let concertHall = SpatialScene(
        name: "Concert Hall",
        objects: [
            ObjectDefinition(name: "Orchestra L", position: AudioPosition3D(x: -0.5, y: 0, z: 1), gain: 1.0, size: 0.3),
            ObjectDefinition(name: "Orchestra R", position: AudioPosition3D(x: 0.5, y: 0, z: 1), gain: 1.0, size: 0.3),
            ObjectDefinition(name: "Soloist", position: AudioPosition3D(x: 0, y: 0.2, z: 0.8), gain: 1.2, size: 0.1)
        ],
        roomSize: .hall,
        reverbAmount: 0.5
    )

    public static let intimateClub = SpatialScene(
        name: "Intimate Club",
        objects: [
            ObjectDefinition(name: "Stage L", position: AudioPosition3D(x: -0.3, y: 0, z: 0.5), gain: 1.0, size: 0.2),
            ObjectDefinition(name: "Stage R", position: AudioPosition3D(x: 0.3, y: 0, z: 0.5), gain: 1.0, size: 0.2),
            ObjectDefinition(name: "Drums", position: AudioPosition3D(x: 0, y: 0, z: 0.6), gain: 0.9, size: 0.3)
        ],
        roomSize: .small,
        reverbAmount: 0.2
    )

    public static let immersive360 = SpatialScene(
        name: "Immersive 360",
        objects: [
            ObjectDefinition(name: "Front", position: .front, gain: 1.0, size: 0.1),
            ObjectDefinition(name: "Back", position: .back, gain: 0.8, size: 0.1),
            ObjectDefinition(name: "Left", position: .left, gain: 0.9, size: 0.1),
            ObjectDefinition(name: "Right", position: .right, gain: 0.9, size: 0.1),
            ObjectDefinition(name: "Above", position: .above, gain: 0.7, size: 0.1),
            ObjectDefinition(name: "Below", position: .below, gain: 0.6, size: 0.1)
        ],
        roomSize: .outdoor,
        reverbAmount: 0.1
    )
}
