import Foundation
import Accelerate
import simd

/// Room acoustics simulation using the Image Source Method (ISM).
///
/// Models early reflections in a rectangular room by computing virtual
/// mirror-image sources and their arrival times, gains, and directions.
///
/// Reflection Model:
/// ```
/// Source → Direct → Listener (dry)
///        → Wall reflection → Listener (1st order)
///        → Wall → Wall reflection → Listener (2nd order)
///        → ... up to maxReflectionOrder
/// ```
///
/// Each reflection is attenuated by wall absorption and inverse-square distance.
class RoomSimulation {

    // MARK: - Types

    struct RoomGeometry {
        var width: Float = 8.0       // X dimension (meters)
        var depth: Float = 10.0      // Y dimension (meters)
        var height: Float = 3.5      // Z dimension (meters)

        static let smallRoom = RoomGeometry(width: 4.0, depth: 5.0, height: 2.8)
        static let mediumRoom = RoomGeometry(width: 8.0, depth: 10.0, height: 3.5)
        static let largeHall = RoomGeometry(width: 20.0, depth: 30.0, height: 12.0)
        static let cathedral = RoomGeometry(width: 15.0, depth: 40.0, height: 25.0)
        static let studio = RoomGeometry(width: 6.0, depth: 7.0, height: 3.0)
    }

    struct WallMaterials {
        /// Absorption coefficients per wall (0 = fully reflective, 1 = fully absorptive)
        var leftWall: Float = 0.3
        var rightWall: Float = 0.3
        var frontWall: Float = 0.2
        var backWall: Float = 0.2
        var floor: Float = 0.5
        var ceiling: Float = 0.4

        static let concrete = WallMaterials(leftWall: 0.02, rightWall: 0.02, frontWall: 0.02, backWall: 0.02, floor: 0.02, ceiling: 0.02)
        static let wood = WallMaterials(leftWall: 0.15, rightWall: 0.15, frontWall: 0.15, backWall: 0.15, floor: 0.1, ceiling: 0.15)
        static let carpet = WallMaterials(leftWall: 0.3, rightWall: 0.3, frontWall: 0.3, backWall: 0.3, floor: 0.7, ceiling: 0.3)
        static let studio = WallMaterials(leftWall: 0.5, rightWall: 0.5, frontWall: 0.4, backWall: 0.6, floor: 0.3, ceiling: 0.5)
        static let anechoic = WallMaterials(leftWall: 0.99, rightWall: 0.99, frontWall: 0.99, backWall: 0.99, floor: 0.99, ceiling: 0.99)
    }

    struct ImageSource {
        let position: SIMD3<Float>       // Virtual source position
        let distance: Float              // Distance to listener
        let delaySamples: Int            // Delay in samples
        let gain: Float                  // Attenuation (distance + absorption)
        let reflectionOrder: Int         // Number of wall bounces
        let azimuth: Float               // Direction from listener (degrees)
        let elevation: Float             // Elevation from listener (degrees)
        let wallSequence: [WallType]     // Which walls were hit
    }

    enum WallType: String {
        case left, right, front, back, floor, ceiling
    }

    struct Configuration {
        var room: RoomGeometry = .mediumRoom
        var materials: WallMaterials = .wood
        var maxReflectionOrder: Int = 3      // Max number of wall bounces
        var speedOfSound: Float = 343.0      // m/s
        var airAbsorption: Float = 0.002     // dB/m at high frequencies
        var dryGain: Float = 1.0
        var earlyReflectionGain: Float = 0.6
        var lateReverbMix: Float = 0.3
        var minGainThreshold: Float = 0.001  // Skip reflections below this

        static let `default` = Configuration()
        static let liveRoom = Configuration(room: .mediumRoom, materials: .wood, maxReflectionOrder: 4, earlyReflectionGain: 0.7)
        static let deadRoom = Configuration(room: .studio, materials: .studio, maxReflectionOrder: 2, earlyReflectionGain: 0.3)
        static let cathedral = Configuration(room: .cathedral, materials: .concrete, maxReflectionOrder: 5, earlyReflectionGain: 0.8, lateReverbMix: 0.5)
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double

    /// Cached image sources (recomputed when source/listener/room changes)
    private var imageSources: [ImageSource] = []

    /// Delay line buffers for each reflection
    private var delayBuffers: [[Float]]
    private var delayWritePositions: [Int]
    private let maxDelaySamples: Int

    // MARK: - Initialization

    init(sampleRate: Double = 48000, configuration: Configuration = .default) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        // Max delay: diagonal of room * max order / speed of sound
        let maxDim = max(configuration.room.width, max(configuration.room.depth, configuration.room.height))
        let maxDistance = maxDim * Float(configuration.maxReflectionOrder) * 1.8
        self.maxDelaySamples = Int(Double(maxDistance / configuration.speedOfSound) * sampleRate) + 1
        self.delayBuffers = []
        self.delayWritePositions = []
    }

    // MARK: - Image Source Computation

    /// Compute all image sources for a source/listener pair.
    ///
    /// - Parameters:
    ///   - sourcePosition: Sound source position in room coordinates
    ///   - listenerPosition: Listener position in room coordinates
    func computeImageSources(
        sourcePosition: SIMD3<Float>,
        listenerPosition: SIMD3<Float>
    ) {
        imageSources.removeAll()

        let room = configuration.room
        let materials = configuration.materials

        // Generate image sources up to maxReflectionOrder
        computeReflections(
            source: sourcePosition,
            listener: listenerPosition,
            room: room,
            materials: materials,
            order: 0,
            currentGain: 1.0,
            wallHistory: []
        )

        // Sort by arrival time
        imageSources.sort { $0.delaySamples < $1.delaySamples }

        // Allocate delay buffers
        delayBuffers = Array(repeating: [Float](repeating: 0, count: maxDelaySamples), count: imageSources.count)
        delayWritePositions = Array(repeating: 0, count: imageSources.count)
    }

    private func computeReflections(
        source: SIMD3<Float>,
        listener: SIMD3<Float>,
        room: RoomGeometry,
        materials: WallMaterials,
        order: Int,
        currentGain: Float,
        wallHistory: [WallType]
    ) {
        guard order <= configuration.maxReflectionOrder else { return }

        if order > 0 {
            // This is a valid image source
            let toListener = listener - source
            let distance = simd_length(toListener)
            guard distance > 0.01 else { return }

            // Inverse-square distance attenuation
            let distanceGain = 1.0 / max(distance, 0.1)

            // Air absorption (high-frequency loss over distance)
            let airLoss = powf(10.0, -configuration.airAbsorption * distance / 20.0)

            let totalGain = currentGain * distanceGain * airLoss

            guard totalGain > configuration.minGainThreshold else { return }

            let delaySamples = Int(Double(distance / configuration.speedOfSound) * sampleRate)
            guard delaySamples < maxDelaySamples else { return }

            // Compute direction from listener
            let direction = simd_normalize(source - listener)
            let azimuth = atan2(direction.y, direction.x) * 180.0 / .pi
            let elevation = asin(direction.z / max(simd_length(direction), 0.001)) * 180.0 / .pi

            imageSources.append(ImageSource(
                position: source,
                distance: distance,
                delaySamples: delaySamples,
                gain: totalGain,
                reflectionOrder: order,
                azimuth: azimuth,
                elevation: elevation,
                wallSequence: wallHistory
            ))
        }

        guard order < configuration.maxReflectionOrder else { return }

        // Reflect across each wall
        let walls: [(WallType, SIMD3<Float>, Float)] = [
            (.left,    SIMD3<Float>(1, 0, 0),  0),                    // x = 0
            (.right,   SIMD3<Float>(1, 0, 0),  room.width),           // x = width
            (.front,   SIMD3<Float>(0, 1, 0),  room.depth),           // y = depth
            (.back,    SIMD3<Float>(0, 1, 0),  0),                    // y = 0
            (.floor,   SIMD3<Float>(0, 0, 1),  0),                    // z = 0
            (.ceiling, SIMD3<Float>(0, 0, 1),  room.height),          // z = height
        ]

        for (wallType, normal, wallPos) in walls {
            // Don't reflect off the same wall consecutively
            if let lastWall = wallHistory.last, lastWall == wallType { continue }

            let reflected = reflectAcrossPlane(source, normal: normal, planeOffset: wallPos)
            let absorption = absorptionForWall(wallType, materials: materials)
            let reflGain = currentGain * (1.0 - absorption)

            guard reflGain > configuration.minGainThreshold else { continue }

            computeReflections(
                source: reflected,
                listener: listener,
                room: room,
                materials: materials,
                order: order + 1,
                currentGain: reflGain,
                wallHistory: wallHistory + [wallType]
            )
        }
    }

    /// Reflect a point across a plane defined by normal and offset.
    private func reflectAcrossPlane(_ point: SIMD3<Float>, normal: SIMD3<Float>, planeOffset: Float) -> SIMD3<Float> {
        let d = simd_dot(point, normal) - planeOffset
        return point - 2.0 * d * normal
    }

    private func absorptionForWall(_ wall: WallType, materials: WallMaterials) -> Float {
        switch wall {
        case .left:    return materials.leftWall
        case .right:   return materials.rightWall
        case .front:   return materials.frontWall
        case .back:    return materials.backWall
        case .floor:   return materials.floor
        case .ceiling: return materials.ceiling
        }
    }

    // MARK: - Processing

    /// Process a mono input buffer through the room simulation.
    /// Returns early reflections mixed with the dry signal.
    func processBuffer(_ input: [Float]) -> [Float] {
        let count = input.count
        var output = [Float](repeating: 0, count: count)

        // Add dry signal
        var dryGain = configuration.dryGain
        output.withUnsafeMutableBufferPointer { buf in
            vDSP_vsma(input, 1, &dryGain, buf.baseAddress!, 1, buf.baseAddress!, 1, vDSP_Length(count))
        }

        // Add each image source reflection
        for (index, source) in imageSources.enumerated() {
            guard index < delayBuffers.count else { break }

            let gain = source.gain * configuration.earlyReflectionGain

            for i in 0..<count {
                // Write input to delay buffer
                delayBuffers[index][delayWritePositions[index]] = input[i]

                // Read delayed sample
                let readPos = (delayWritePositions[index] - source.delaySamples + maxDelaySamples) % maxDelaySamples
                output[i] += delayBuffers[index][readPos] * gain

                // Advance write position
                delayWritePositions[index] = (delayWritePositions[index] + 1) % maxDelaySamples
            }
        }

        return output
    }

    /// Process and return separate direct + early reflection outputs.
    func processSeparate(_ input: [Float]) -> (direct: [Float], earlyReflections: [Float]) {
        let count = input.count
        var direct = [Float](repeating: 0, count: count)
        var early = [Float](repeating: 0, count: count)

        var dryGainSep = configuration.dryGain
        direct.withUnsafeMutableBufferPointer { buf in
            vDSP_vsma(input, 1, &dryGainSep, buf.baseAddress!, 1, buf.baseAddress!, 1, vDSP_Length(count))
        }

        for (index, source) in imageSources.enumerated() {
            guard index < delayBuffers.count else { break }

            let gain = source.gain * configuration.earlyReflectionGain

            for i in 0..<count {
                delayBuffers[index][delayWritePositions[index]] = input[i]
                let readPos = (delayWritePositions[index] - source.delaySamples + maxDelaySamples) % maxDelaySamples
                early[i] += delayBuffers[index][readPos] * gain
                delayWritePositions[index] = (delayWritePositions[index] + 1) % maxDelaySamples
            }
        }

        return (direct, early)
    }

    // MARK: - Room Acoustics Info

    /// Estimate RT60 (reverberation time) using Sabine's equation.
    var estimatedRT60: Float {
        let room = configuration.room
        let mat = configuration.materials
        let volume = room.width * room.depth * room.height

        // Surface areas
        let floorCeiling = 2.0 * room.width * room.depth
        let frontBack = 2.0 * room.width * room.height
        let leftRight = 2.0 * room.depth * room.height

        // Total absorption (Sabine)
        let totalAbsorption = floorCeiling * (mat.floor + mat.ceiling) / 2.0
            + frontBack * (mat.frontWall + mat.backWall) / 2.0
            + leftRight * (mat.leftWall + mat.rightWall) / 2.0

        guard totalAbsorption > 0.01 else { return 10.0 }

        // Sabine formula: RT60 = 0.161 * V / A
        return 0.161 * volume / totalAbsorption
    }

    /// Number of computed image sources.
    var imageSourceCount: Int { imageSources.count }

    // MARK: - Reset

    func reset() {
        imageSources.removeAll()
        delayBuffers.removeAll()
        delayWritePositions.removeAll()
    }
}
