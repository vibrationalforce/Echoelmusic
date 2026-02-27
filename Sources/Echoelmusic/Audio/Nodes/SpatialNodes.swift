import Foundation
import AVFoundation
import Accelerate

// MARK: - AmbisonicsNode

/// Ambisonics encoding/decoding node for the audio graph.
/// Wraps AmbisonicsProcessor to conform to EchoelmusicNode protocol.
/// Bio-reactive: HRV coherence modulates spatial width via encoding gain.
@MainActor
class AmbisonicsNode: BaseEchoelmusicNode {

    private let processor = AmbisonicsProcessor()
    private var sRate: Double = 44100.0

    /// Source position for encoding (set externally or via bio-reactivity)
    var sourcePosition: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 1.0) // 1m in front

    /// Listener orientation for head tracking
    var listenerYaw: Float = 0.0
    var listenerPitch: Float = 0.0

    private enum Params {
        static let azimuth = "azimuth"
        static let elevation = "elevation"
        static let distance = "distance"
        static let width = "width"
    }

    override var isBioReactive: Bool { true }

    init() {
        super.init(name: "Ambisonics", type: .effect)

        parameters = [
            NodeParameter(
                name: Params.azimuth, label: "Azimuth",
                value: 0.0, min: -180.0, max: 180.0, defaultValue: 0.0,
                unit: "°", isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.elevation, label: "Elevation",
                value: 0.0, min: -90.0, max: 90.0, defaultValue: 0.0,
                unit: "°", isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.distance, label: "Distance",
                value: 1.0, min: 0.1, max: 50.0, defaultValue: 1.0,
                unit: "m", isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.width, label: "Width",
                value: 1.0, min: 0.0, max: 2.0, defaultValue: 1.0,
                unit: nil, isAutomatable: true, type: .continuous
            ),
        ]
    }

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sRate = sampleRate
    }

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else { return buffer }
        guard let channelData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return buffer }

        // Extract mono from first channel
        let input = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        let azimuth = getParameter(name: Params.azimuth) ?? 0.0
        let elevation = getParameter(name: Params.elevation) ?? 0.0
        let distance = getParameter(name: Params.distance) ?? 1.0

        // Encode to B-format and decode to stereo
        let bFormat = processor.encode(input, azimuth: azimuth, elevation: elevation, distance: distance)
        let rotated = processor.rotateBFormat(bFormat, yaw: listenerYaw, pitch: listenerPitch, roll: 0.0)
        let stereo = processor.decodeToStereo(rotated)

        // Write stereo output (create stereo buffer if needed)
        let channelCount = Int(buffer.format.channelCount)
        let leftOutput = stereo.left
        let rightOutput = stereo.right

        guard leftOutput.count >= frameCount else { return buffer }

        // Write left channel
        for i in 0..<frameCount {
            channelData[0][i] = leftOutput[i]
        }

        // Write right channel if stereo
        if channelCount >= 2 {
            for i in 0..<frameCount {
                channelData[1][i] = rightOutput[i]
            }
        }

        return buffer
    }

    override func react(to signal: BioSignal) {
        // Coherence modulates spatial width — higher coherence = wider field
        let coherenceNorm = Float(signal.coherence / 100.0) // 0-1
        let widthFactor = 0.5 + coherenceNorm * 1.5 // 0.5 to 2.0
        setParameter(name: Params.width, value: widthFactor)
    }
}


// MARK: - RoomSimulationNode

/// Room simulation node wrapping the Image Source Method (ISM) processor.
/// Bio-reactive: HRV coherence modulates room size (higher coherence = more spacious).
@MainActor
class RoomSimulationNode: BaseEchoelmusicNode {

    private let roomSim = RoomSimulation()
    private var sRate: Double = 44100.0
    private var isConfigured: Bool = false

    /// Source position in room coordinates
    var sourcePosition: SIMD3<Float> = SIMD3<Float>(2.0, 2.5, 1.0)

    /// Listener position in room coordinates
    var listenerPosition: SIMD3<Float> = SIMD3<Float>(4.0, 2.5, 1.0)

    private enum Params {
        static let roomSize = "roomSize"
        static let earlyGain = "earlyGain"
        static let dryWet = "dryWet"
    }

    override var isBioReactive: Bool { true }

    init() {
        super.init(name: "Room Simulation", type: .effect)

        parameters = [
            NodeParameter(
                name: Params.roomSize, label: "Room Size",
                value: 1.0, min: 0.0, max: 4.0, defaultValue: 1.0,
                unit: nil, isAutomatable: true, type: .discrete
            ),
            NodeParameter(
                name: Params.earlyGain, label: "Early Gain",
                value: 0.6, min: 0.0, max: 1.0, defaultValue: 0.6,
                unit: nil, isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.dryWet, label: "Dry/Wet",
                value: 0.3, min: 0.0, max: 1.0, defaultValue: 0.3,
                unit: nil, isAutomatable: true, type: .continuous
            ),
        ]
    }

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sRate = sampleRate
        configureDefaultRoom()
    }

    override func start() {
        super.start()
        if !isConfigured {
            configureDefaultRoom()
        }
    }

    private func configureDefaultRoom() {
        let roomSizeParam = getParameter(name: Params.roomSize) ?? 1.0
        let geometry: RoomSimulation.RoomGeometry
        switch Int(roomSizeParam) {
        case 0: geometry = .smallRoom
        case 1: geometry = .mediumRoom
        case 2: geometry = .largeHall
        case 3: geometry = .cathedral
        default: geometry = .studio
        }
        roomSim.configuration.room = geometry
        roomSim.configuration.materials = .wood
        roomSim.computeImageSources(sourcePosition: sourcePosition, listenerPosition: listenerPosition)
        isConfigured = true
    }

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive, isConfigured else { return buffer }
        guard let channelData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return buffer }

        let dryWet = getParameter(name: Params.dryWet) ?? 0.3

        // Process each channel
        let channelCount = Int(buffer.format.channelCount)
        for ch in 0..<channelCount {
            let input = Array(UnsafeBufferPointer(start: channelData[ch], count: frameCount))
            let processed = roomSim.processBuffer(input)

            guard processed.count >= frameCount else { continue }

            // Blend dry/wet
            for i in 0..<frameCount {
                channelData[ch][i] = input[i] * (1.0 - dryWet) + processed[i] * dryWet
            }
        }

        return buffer
    }

    override func react(to signal: BioSignal) {
        // Higher coherence = larger/more spacious room feel
        let coherenceNorm = Float(signal.coherence / 100.0)
        // Map coherence to room size: low coherence → small room, high → large hall
        let roomIndex = Float(Int(coherenceNorm * 3.0)) // 0, 1, 2, or 3
        let currentSize = getParameter(name: Params.roomSize) ?? 1.0
        if abs(roomIndex - currentSize) > 0.5 {
            setParameter(name: Params.roomSize, value: roomIndex)
            configureDefaultRoom()
        }
    }
}


// MARK: - DopplerNode

/// Doppler effect node wrapping DopplerProcessor.
/// Bio-reactive: breathing phase modulates source velocity for organic motion.
@MainActor
class DopplerNode: BaseEchoelmusicNode {

    private let processor = DopplerProcessor()
    private var sRate: Double = 44100.0

    /// Unique source ID for smoothed tracking
    private let sourceID = UUID()

    /// Source position and velocity (set externally or via bio-reactivity)
    var sourcePosition: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 1.0)
    var sourceVelocity: SIMD3<Float> = .zero
    var listenerPosition: SIMD3<Float> = .zero
    var listenerVelocity: SIMD3<Float> = .zero

    private enum Params {
        static let intensity = "intensity"
        static let smoothing = "smoothing"
    }

    override var isBioReactive: Bool { true }

    init() {
        super.init(name: "Doppler Effect", type: .effect)

        parameters = [
            NodeParameter(
                name: Params.intensity, label: "Intensity",
                value: 1.0, min: 0.0, max: 2.0, defaultValue: 1.0,
                unit: nil, isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.smoothing, label: "Smoothing",
                value: 0.95, min: 0.0, max: 0.99, defaultValue: 0.95,
                unit: nil, isAutomatable: true, type: .continuous
            ),
        ]
    }

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sRate = sampleRate
    }

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else { return buffer }
        guard let channelData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return buffer }

        // Process each channel through Doppler shift
        let channelCount = Int(buffer.format.channelCount)
        for ch in 0..<channelCount {
            let input = Array(UnsafeBufferPointer(start: channelData[ch], count: frameCount))

            let shifted = processor.processSource(
                input,
                sourceID: sourceID,
                sourcePosition: sourcePosition,
                sourceVelocity: sourceVelocity,
                listenerPosition: listenerPosition,
                listenerVelocity: listenerVelocity
            )

            guard shifted.count >= frameCount else { continue }

            for i in 0..<frameCount {
                channelData[ch][i] = shifted[i]
            }
        }

        return buffer
    }

    override func react(to signal: BioSignal) {
        // Breathing phase modulates source velocity for organic spatial motion
        let breathPhase = Float(signal.respiratoryRate ?? 15.0) / 30.0 // normalize
        let intensity = getParameter(name: Params.intensity) ?? 1.0

        // Create gentle orbital velocity modulated by breath
        let speed = breathPhase * intensity * 2.0
        sourceVelocity = SIMD3<Float>(
            sin(breathPhase * .pi * 2.0) * speed,
            0.0,
            cos(breathPhase * .pi * 2.0) * speed
        )
    }
}


// MARK: - HRTFNode

/// HRTF binaural spatialization node wrapping HRTFProcessor.
/// Produces stereo output with head-tracked binaural rendering.
/// Bio-reactive: coherence modulates spatial width.
@MainActor
class HRTFNode: BaseEchoelmusicNode {

    private let processor = HRTFProcessor()
    private var sRate: Double = 44100.0

    /// Source for spatialization
    var spatialSource = SpatialSource(
        id: UUID(),
        position: SIMD3<Float>(0.0, 0.0, 1.0)
    )

    private enum Params {
        static let azimuth = "azimuth"
        static let elevation = "elevation"
        static let distance = "distance"
        static let spread = "spread"
    }

    override var isBioReactive: Bool { true }

    init() {
        super.init(name: "HRTF Binaural", type: .effect)

        parameters = [
            NodeParameter(
                name: Params.azimuth, label: "Azimuth",
                value: 0.0, min: -180.0, max: 180.0, defaultValue: 0.0,
                unit: "°", isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.elevation, label: "Elevation",
                value: 0.0, min: -90.0, max: 90.0, defaultValue: 0.0,
                unit: "°", isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.distance, label: "Distance",
                value: 1.0, min: 0.1, max: 50.0, defaultValue: 1.0,
                unit: "m", isAutomatable: true, type: .continuous
            ),
            NodeParameter(
                name: Params.spread, label: "Spread",
                value: 0.0, min: 0.0, max: 1.0, defaultValue: 0.0,
                unit: nil, isAutomatable: true, type: .continuous
            ),
        ]
    }

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sRate = sampleRate
    }

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else { return buffer }
        guard let channelData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return buffer }

        // Update source parameters
        let azimuth = getParameter(name: Params.azimuth) ?? 0.0
        let elevation = getParameter(name: Params.elevation) ?? 0.0
        let distance = getParameter(name: Params.distance) ?? 1.0
        let spread = getParameter(name: Params.spread) ?? 0.0

        spatialSource.azimuth = azimuth
        spatialSource.elevation = elevation
        spatialSource.distance = distance
        spatialSource.spread = spread

        // Convert azimuth/elevation/distance to Cartesian
        let azRad = azimuth * .pi / 180.0
        let elRad = elevation * .pi / 180.0
        spatialSource.position = SIMD3<Float>(
            distance * cos(elRad) * sin(azRad),
            distance * sin(elRad),
            distance * cos(elRad) * cos(azRad)
        )

        // Ensure we have at least 2 channels for stereo output
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount >= 2 else { return buffer }

        // Extract mono input from first channel
        let inputPtr = UnsafeBufferPointer(start: channelData[0], count: frameCount)
        let leftPtr = UnsafeMutableBufferPointer(start: channelData[0], count: frameCount)
        let rightPtr = UnsafeMutableBufferPointer(start: channelData[1], count: frameCount)

        // Clear output before accumulation
        vDSP_vclr(leftPtr.baseAddress!, 1, vDSP_Length(frameCount))
        vDSP_vclr(rightPtr.baseAddress!, 1, vDSP_Length(frameCount))

        // Process through HRTF (writes stereo output to left/right buffers)
        // Need to copy input first since we're about to overwrite channel 0
        let inputCopy = Array(inputPtr)
        inputCopy.withUnsafeBufferPointer { safeInputPtr in
            processor.processSource(
                spatialSource,
                input: safeInputPtr,
                outputLeft: leftPtr,
                outputRight: rightPtr
            )
        }

        return buffer
    }

    override func react(to signal: BioSignal) {
        // Higher coherence = wider spatial field
        let coherenceNorm = Float(signal.coherence / 100.0)
        let spreadValue = coherenceNorm * 0.5 // 0 to 0.5
        setParameter(name: Params.spread, value: spreadValue)

        // Heart rate modulates subtle azimuth drift
        let hrNorm = Float(signal.heartRate - 60.0) / 60.0 // 0-1 for 60-120 BPM range
        let azimuthDrift = hrNorm * 10.0 // ±10° drift
        let currentAzimuth = getParameter(name: Params.azimuth) ?? 0.0
        let smoothed = currentAzimuth * 0.95 + azimuthDrift * 0.05
        setParameter(name: Params.azimuth, value: smoothed)
    }
}
