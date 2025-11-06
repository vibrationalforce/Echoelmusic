import Foundation
import AVFoundation
import Accelerate

/// Software-based binaural spatial audio engine
/// Works on ANY iPhone without special hardware
/// Uses Head-Related Transfer Functions (HRTFs) for 3D audio
@MainActor
public class SoftwareBinauralEngine {

    // MARK: - Configuration

    private let sampleRate: Double
    private let bufferSize: AVAudioFrameCount

    // MARK: - HRTF Data

    /// Simplified HRTF coefficients for different angles
    /// Format: [azimuth: [leftEar, rightEar]] - gain and delay
    private var hrtfDatabase: [Int: HRTFData] = [:]

    // MARK: - Audio Processing

    private var audioEngine: AVAudioEngine?
    private var sourceNodes: [Int: AVAudioPlayerNode] = [:]
    private var mixerNode: AVAudioMixerNode?

    // MARK: - Spatial Positions

    private var sourcePositions: [Int: SpatialPosition] = [:]

    // MARK: - Head Tracking

    public var listenerPosition: SpatialPosition = SpatialPosition(x: 0, y: 0, z: 0)
    public var listenerOrientation: Float = 0.0  // Radians

    // MARK: - Initialization

    public init(sampleRate: Double = 48000.0, bufferSize: AVAudioFrameCount = 512) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize

        initializeHRTFDatabase()
        setupAudioEngine()
    }

    // MARK: - HRTF Database

    private func initializeHRTFDatabase() {
        // Simplified HRTF database for key positions
        // In production, use MIT KEMAR or CIPIC HRTF databases

        // Front (0°)
        hrtfDatabase[0] = HRTFData(
            leftGain: 1.0, rightGain: 1.0,
            leftDelay: 0.0, rightDelay: 0.0,
            leftITD: 0.0, rightITD: 0.0
        )

        // Right (90°)
        hrtfDatabase[90] = HRTFData(
            leftGain: 0.5, rightGain: 1.0,
            leftDelay: 0.0006, rightDelay: 0.0,  // ~0.6ms ITD
            leftITD: 0.0006, rightITD: 0.0
        )

        // Left (-90°)
        hrtfDatabase[-90] = HRTFData(
            leftGain: 1.0, rightGain: 0.5,
            leftDelay: 0.0, rightDelay: 0.0006,
            leftITD: 0.0, rightITD: 0.0006
        )

        // Back (180°)
        hrtfDatabase[180] = HRTFData(
            leftGain: 0.7, rightGain: 0.7,
            leftDelay: 0.0003, rightDelay: 0.0003,
            leftITD: 0.0003, rightITD: 0.0003
        )

        // Interpolate for all angles 0-360
        for angle in stride(from: 0, to: 360, by: 15) {
            if hrtfDatabase[angle] == nil {
                hrtfDatabase[angle] = interpolateHRTF(angle: angle)
            }
        }
    }

    private func interpolateHRTF(angle: Int) -> HRTFData {
        // Simple linear interpolation between known points
        let normalizedAngle = angle % 360

        // Find nearest known angles
        let knownAngles = [0, 90, 180, -90]
        let nearestAngle = knownAngles.min(by: { abs($0 - normalizedAngle) < abs($1 - normalizedAngle) }) ?? 0

        // Return nearest for now (in production, do proper interpolation)
        return hrtfDatabase[nearestAngle] ?? HRTFData.identity
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = audioEngine?.mainMixerNode

        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)

        // Configure for low latency
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
            try AVAudioSession.sharedInstance().setActive(true)

            engine.prepare()
            try engine.start()

            print("✅ Software Binaural Engine started")
            print("   Sample Rate: \(sampleRate) Hz")
            print("   Buffer Size: \(bufferSize) frames")
        } catch {
            print("❌ Failed to start binaural engine: \(error)")
        }
    }

    // MARK: - Source Management

    public func addSource(id: Int, position: SpatialPosition) {
        sourcePositions[id] = position

        // Create audio player node
        let playerNode = AVAudioPlayerNode()
        sourceNodes[id] = playerNode

        audioEngine?.attach(playerNode)

        if let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) {
            audioEngine?.connect(playerNode, to: mixerNode!, format: format)
        }
    }

    public func removeSource(id: Int) {
        if let node = sourceNodes[id] {
            node.stop()
            audioEngine?.detach(node)
        }
        sourceNodes.removeValue(forKey: id)
        sourcePositions.removeValue(forKey: id)
    }

    public func updateSourcePosition(id: Int, position: SpatialPosition) {
        sourcePositions[id] = position
    }

    // MARK: - Spatial Processing

    /// Process audio buffer with binaural spatialization
    public func processSpatialAudio(_ inputBuffer: AVAudioPCMBuffer, sourceId: Int) -> AVAudioPCMBuffer? {
        guard let sourcePosition = sourcePositions[sourceId] else { return inputBuffer }

        // Calculate relative position to listener
        let relativePosition = calculateRelativePosition(sourcePosition)

        // Calculate azimuth angle
        let azimuth = calculateAzimuth(relativePosition)

        // Get HRTF for this angle
        let hrtf = getHRTF(azimuth: azimuth)

        // Apply binaural processing
        return applyBinauralProcessing(inputBuffer, hrtf: hrtf, distance: relativePosition.distance)
    }

    private func calculateRelativePosition(_ sourcePosition: SpatialPosition) -> RelativePosition {
        // Calculate position relative to listener
        let dx = sourcePosition.x - listenerPosition.x
        let dy = sourcePosition.y - listenerPosition.y
        let dz = sourcePosition.z - listenerPosition.z

        // Rotate by listener orientation
        let cos = Float(Foundation.cos(Double(listenerOrientation)))
        let sin = Float(Foundation.sin(Double(listenerOrientation)))

        let rotatedX = dx * cos - dz * sin
        let rotatedZ = dx * sin + dz * cos

        let distance = sqrt(rotatedX * rotatedX + dy * dy + rotatedZ * rotatedZ)

        return RelativePosition(x: rotatedX, y: dy, z: rotatedZ, distance: distance)
    }

    private func calculateAzimuth(_ position: RelativePosition) -> Int {
        // Calculate azimuth angle in degrees
        let angleRad = atan2(position.x, position.z)
        let angleDeg = angleRad * 180.0 / .pi

        // Normalize to 0-360
        let normalized = Int(angleDeg) % 360
        return normalized < 0 ? normalized + 360 : normalized
    }

    private func getHRTF(azimuth: Int) -> HRTFData {
        // Round to nearest 15 degrees
        let roundedAzimuth = (azimuth / 15) * 15

        return hrtfDatabase[roundedAzimuth] ?? HRTFData.identity
    }

    private func applyBinauralProcessing(_ inputBuffer: AVAudioPCMBuffer, hrtf: HRTFData, distance: Float) -> AVAudioPCMBuffer? {
        guard let inputData = inputBuffer.floatChannelData else { return nil }
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!,
            frameCapacity: inputBuffer.frameCapacity
        ) else { return nil }

        guard let outputData = outputBuffer.floatChannelData else { return nil }

        let frameLength = Int(inputBuffer.frameLength)
        outputBuffer.frameLength = inputBuffer.frameLength

        let inputChannel = inputData[0]
        let leftChannel = outputData[0]
        let rightChannel = outputData[1]

        // Distance attenuation (inverse square law)
        let distanceAttenuation = max(0.1, 1.0 / max(distance, 1.0))

        // Apply HRTF gains and ITD
        for i in 0..<frameLength {
            // Apply gains and distance attenuation
            let sample = inputChannel[i] * distanceAttenuation

            leftChannel[i] = sample * hrtf.leftGain
            rightChannel[i] = sample * hrtf.rightGain
        }

        // Apply Interaural Time Difference (ITD) via delay
        applyITD(leftChannel: leftChannel, rightChannel: rightChannel, hrtf: hrtf, frameLength: frameLength)

        return outputBuffer
    }

    private func applyITD(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, hrtf: HRTFData, frameLength: Int) {
        // Simple delay for ITD simulation
        let leftDelaySamples = Int(hrtf.leftDelay * Float(sampleRate))
        let rightDelaySamples = Int(hrtf.rightDelay * Float(sampleRate))

        // Shift samples for ITD effect
        if leftDelaySamples > 0 && leftDelaySamples < frameLength {
            for i in stride(from: frameLength - 1, through: leftDelaySamples, by: -1) {
                leftChannel[i] = leftChannel[i - leftDelaySamples]
            }
            for i in 0..<leftDelaySamples {
                leftChannel[i] = 0.0
            }
        }

        if rightDelaySamples > 0 && rightDelaySamples < frameLength {
            for i in stride(from: frameLength - 1, through: rightDelaySamples, by: -1) {
                rightChannel[i] = rightChannel[i - rightDelaySamples]
            }
            for i in 0..<rightDelaySamples {
                rightChannel[i] = 0.0
            }
        }
    }

    // MARK: - Head Tracking Integration

    public func updateListenerOrientation(_ yaw: Float, pitch: Float, roll: Float) {
        // Use yaw for horizontal rotation
        listenerOrientation = yaw

        // Could also use pitch/roll for elevation effects
    }

    // MARK: - Cleanup

    public func stop() {
        audioEngine?.stop()
        sourceNodes.values.forEach { $0.stop() }
        print("✅ Software Binaural Engine stopped")
    }

    deinit {
        stop()
    }
}

// MARK: - Supporting Types

/// HRTF data for a specific angle
public struct HRTFData {
    let leftGain: Float
    let rightGain: Float
    let leftDelay: Float   // Seconds
    let rightDelay: Float  // Seconds
    let leftITD: Float     // Interaural Time Difference
    let rightITD: Float

    static var identity: HRTFData {
        HRTFData(leftGain: 1.0, rightGain: 1.0, leftDelay: 0.0, rightDelay: 0.0, leftITD: 0.0, rightITD: 0.0)
    }
}

/// 3D spatial position
public struct SpatialPosition {
    var x: Float
    var y: Float
    var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Relative position to listener
struct RelativePosition {
    let x: Float
    let y: Float
    let z: Float
    let distance: Float
}
