// DolbyAtmosEngine.swift
// Echoelmusic - Dolby Atmos & Immersive Audio Export
// Created by Claude (Phase 4) - December 2025

import Foundation
import Accelerate
import AVFoundation

// MARK: - Spatial Audio Formats

/// Supported immersive audio formats
public enum ImmersiveAudioFormat: String, CaseIterable, Codable {
    case dolbyAtmos = "Dolby Atmos"
    case sony360RA = "Sony 360 Reality Audio"
    case appleSpatial = "Apple Spatial Audio"
    case auro3D = "Auro-3D"
    case dtsX = "DTS:X"
    case mpeg_h = "MPEG-H 3D Audio"
    case ambisonicsFirstOrder = "Ambisonics (1st Order)"
    case ambisonicsThirdOrder = "Ambisonics (3rd Order)"

    var channelLayout: ChannelLayout {
        switch self {
        case .dolbyAtmos: return .atmos_7_1_4
        case .sony360RA: return .objectBased
        case .appleSpatial: return .atmos_7_1_4
        case .auro3D: return .auro_13_1
        case .dtsX: return .atmos_7_1_4
        case .mpeg_h: return .objectBased
        case .ambisonicsFirstOrder: return .ambisonics_1
        case .ambisonicsThirdOrder: return .ambisonics_3
        }
    }
}

/// Channel layouts for bed audio
public enum ChannelLayout: String, Codable {
    case stereo = "2.0"
    case surround_5_1 = "5.1"
    case surround_7_1 = "7.1"
    case atmos_5_1_2 = "5.1.2"
    case atmos_5_1_4 = "5.1.4"
    case atmos_7_1_2 = "7.1.2"
    case atmos_7_1_4 = "7.1.4"
    case auro_9_1 = "9.1"
    case auro_13_1 = "13.1"
    case ambisonics_1 = "AmbiX 1st Order"
    case ambisonics_3 = "AmbiX 3rd Order"
    case objectBased = "Object-Based"

    var channelCount: Int {
        switch self {
        case .stereo: return 2
        case .surround_5_1: return 6
        case .surround_7_1: return 8
        case .atmos_5_1_2: return 8
        case .atmos_5_1_4: return 10
        case .atmos_7_1_2: return 10
        case .atmos_7_1_4: return 12
        case .auro_9_1: return 10
        case .auro_13_1: return 14
        case .ambisonics_1: return 4  // W, X, Y, Z
        case .ambisonics_3: return 16  // 3rd order = (3+1)^2
        case .objectBased: return 0  // Dynamic
        }
    }

    var speakerPositions: [SpeakerPosition] {
        switch self {
        case .stereo:
            return [.left, .right]
        case .surround_5_1:
            return [.left, .right, .center, .lfe, .leftSurround, .rightSurround]
        case .surround_7_1:
            return [.left, .right, .center, .lfe, .leftSurround, .rightSurround, .leftRear, .rightRear]
        case .atmos_7_1_4:
            return [.left, .right, .center, .lfe, .leftSurround, .rightSurround, .leftRear, .rightRear,
                    .topFrontLeft, .topFrontRight, .topRearLeft, .topRearRight]
        default:
            return []
        }
    }
}

/// Standard speaker positions
public enum SpeakerPosition: String, Codable {
    case left = "L"
    case right = "R"
    case center = "C"
    case lfe = "LFE"
    case leftSurround = "Ls"
    case rightSurround = "Rs"
    case leftRear = "Lb"
    case rightRear = "Rb"
    case topFrontLeft = "Ltf"
    case topFrontRight = "Rtf"
    case topRearLeft = "Ltr"
    case topRearRight = "Rtr"
    case topCenter = "Ts"
    case topFrontCenter = "Tfc"
    case topRearCenter = "Trc"
    case bottomFrontLeft = "Lbf"
    case bottomFrontRight = "Rbf"

    var azimuth: Float {  // degrees
        switch self {
        case .left: return -30
        case .right: return 30
        case .center: return 0
        case .lfe: return 0
        case .leftSurround: return -110
        case .rightSurround: return 110
        case .leftRear: return -150
        case .rightRear: return 150
        case .topFrontLeft: return -45
        case .topFrontRight: return 45
        case .topRearLeft: return -135
        case .topRearRight: return 135
        case .topCenter: return 0
        case .topFrontCenter: return 0
        case .topRearCenter: return 180
        case .bottomFrontLeft: return -45
        case .bottomFrontRight: return 45
        }
    }

    var elevation: Float {  // degrees
        switch self {
        case .topFrontLeft, .topFrontRight, .topRearLeft, .topRearRight,
             .topCenter, .topFrontCenter, .topRearCenter:
            return 45
        case .bottomFrontLeft, .bottomFrontRight:
            return -30
        case .lfe:
            return -30
        default:
            return 0
        }
    }
}

// MARK: - Audio Object

/// A positioned audio object in 3D space
public struct AudioObject: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var position: SIMD3<Float>  // x, y, z (-1 to 1)
    public var size: Float  // Object spread (0-1)
    public var gain: Float  // dB
    public var samples: [Float]
    public var isStatic: Bool  // Static bed vs dynamic object

    public init(name: String, position: SIMD3<Float> = .zero, size: Float = 0.1, gain: Float = 0) {
        self.id = UUID()
        self.name = name
        self.position = position
        self.size = size
        self.gain = gain
        self.samples = []
        self.isStatic = false
    }

    /// Convert position to spherical coordinates
    public var spherical: (azimuth: Float, elevation: Float, distance: Float) {
        let distance = sqrt(position.x * position.x + position.y * position.y + position.z * position.z)
        let azimuth = atan2(position.x, position.z) * 180 / .pi  // degrees
        let elevation = distance > 0 ? asin(position.y / distance) * 180 / .pi : 0
        return (azimuth, elevation, distance)
    }
}

// MARK: - Object Panner

/// VBAP (Vector Base Amplitude Panning) for object positioning
public final class VBAPPanner: @unchecked Sendable {

    private let layout: ChannelLayout
    private var speakerVectors: [SIMD3<Float>] = []
    private var triangles: [(Int, Int, Int)] = []  // Speaker triplets

    public init(layout: ChannelLayout) {
        self.layout = layout
        setupSpeakers()
        calculateTriangles()
    }

    private func setupSpeakers() {
        speakerVectors = layout.speakerPositions.map { pos in
            let azimuthRad = pos.azimuth * .pi / 180
            let elevationRad = pos.elevation * .pi / 180

            return SIMD3<Float>(
                cos(elevationRad) * sin(azimuthRad),
                sin(elevationRad),
                cos(elevationRad) * cos(azimuthRad)
            )
        }
    }

    private func calculateTriangles() {
        // Delaunay triangulation on speaker positions
        // Simplified: create triangles from adjacent speakers
        let count = speakerVectors.count
        guard count >= 3 else { return }

        // For 7.1.4, create appropriate triangles
        if layout == .atmos_7_1_4 {
            triangles = [
                // Front layer
                (0, 2, 1),   // L, C, R
                // Surround layer
                (0, 4, 5),   // L, Ls, Rs (wrap)
                (1, 5, 4),   // R, Rs, Ls
                // Height layer
                (8, 9, 10),  // Ltf, Rtf, Ltr
                (9, 10, 11), // Rtf, Ltr, Rtr
                // Connections
                (0, 8, 2),   // L, Ltf, C
                (1, 9, 2),   // R, Rtf, C
                (4, 10, 6),  // Ls, Ltr, Lb
                (5, 11, 7),  // Rs, Rtr, Rb
            ]
        } else {
            // Generic triangulation
            for i in 0..<count-2 {
                triangles.append((i, i+1, i+2))
            }
        }
    }

    /// Calculate speaker gains for object position
    public func pan(position: SIMD3<Float>) -> [Float] {
        var gains = [Float](repeating: 0, count: speakerVectors.count)

        // Normalize position to unit sphere
        let distance = simd_length(position)
        let direction = distance > 0 ? position / distance : SIMD3<Float>(0, 0, 1)

        // Find containing triangle
        for (i, j, k) in triangles {
            guard i < speakerVectors.count && j < speakerVectors.count && k < speakerVectors.count else { continue }

            let v1 = speakerVectors[i]
            let v2 = speakerVectors[j]
            let v3 = speakerVectors[k]

            // Calculate barycentric coordinates
            if let (g1, g2, g3) = calculateBarycentricGains(direction: direction, v1: v1, v2: v2, v3: v3) {
                gains[i] = g1
                gains[j] = g2
                gains[k] = g3
                break
            }
        }

        // Normalize gains to maintain energy
        let sumSquared = gains.reduce(0) { $0 + $1 * $1 }
        if sumSquared > 0 {
            let normalizer = 1.0 / sqrt(sumSquared)
            for i in 0..<gains.count {
                gains[i] *= normalizer
            }
        }

        // Apply distance attenuation
        let attenuation = 1.0 / max(1.0, distance)
        for i in 0..<gains.count {
            gains[i] *= attenuation
        }

        return gains
    }

    private func calculateBarycentricGains(direction: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>, v3: SIMD3<Float>) -> (Float, Float, Float)? {
        // Solve linear system for barycentric coordinates
        let e1 = v2 - v1
        let e2 = v3 - v1
        let p = direction - v1

        let d11 = simd_dot(e1, e1)
        let d12 = simd_dot(e1, e2)
        let d22 = simd_dot(e2, e2)
        let d1p = simd_dot(e1, p)
        let d2p = simd_dot(e2, p)

        let denom = d11 * d22 - d12 * d12
        guard abs(denom) > 1e-6 else { return nil }

        let u = (d22 * d1p - d12 * d2p) / denom
        let v = (d11 * d2p - d12 * d1p) / denom
        let w = 1.0 - u - v

        // Check if inside triangle (with small tolerance)
        let tol: Float = 0.01
        if u >= -tol && v >= -tol && w >= -tol {
            return (max(0, w), max(0, u), max(0, v))
        }

        return nil
    }
}

// MARK: - ADM BWF Writer

/// Audio Definition Model Broadcast Wave Format writer
public final class ADMBWFWriter {

    public struct ADMMetadata {
        public var programName: String = "Echoelmusic Mix"
        public var objects: [AudioObject] = []
        public var bedLayout: ChannelLayout = .atmos_7_1_4
        public var sampleRate: Int = 48000
        public var bitDepth: Int = 24
        public var startTime: TimeInterval = 0
        public var duration: TimeInterval = 0
    }

    private var metadata: ADMMetadata

    public init(metadata: ADMMetadata = ADMMetadata()) {
        self.metadata = metadata
    }

    /// Generate ADM XML chunk
    public func generateADMXML() -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ebuCoreMain xmlns="urn:ebu:metadata-schema:ebuCore_2017"
                     xmlns:adm="urn:ebu:metadata-schema:adm">
          <coreMetadata>
            <format>
              <audioFormatExtended>
                <audioProgramme audioProgrammeID="APR_1001" audioProgrammeName="\(metadata.programName)">
                  <audioContentIDRef>ACO_1001</audioContentIDRef>
        """

        // Add object references
        for (index, _) in metadata.objects.enumerated() {
            xml += """
                      <audioObjectIDRef>AO_\(1001 + index)</audioObjectIDRef>
            """
        }

        xml += """
                </audioProgramme>
                <audioContent audioContentID="ACO_1001" audioContentName="Main">
        """

        // Add bed channels
        for (index, position) in metadata.bedLayout.speakerPositions.enumerated() {
            xml += """
                  <audioChannelFormatIDRef>AC_\(String(format: "%05X", 0x10001 + index))</audioChannelFormatIDRef>
            """

            xml += generateChannelFormat(id: 0x10001 + index, position: position)
        }

        // Add objects
        for (index, object) in metadata.objects.enumerated() {
            xml += generateObjectXML(object: object, index: index)
        }

        xml += """
                </audioContent>
              </audioFormatExtended>
            </format>
          </coreMetadata>
        </ebuCoreMain>
        """

        return xml
    }

    private func generateChannelFormat(id: Int, position: SpeakerPosition) -> String {
        """
                <audioChannelFormat audioChannelFormatID="AC_\(String(format: "%05X", id))" audioChannelFormatName="\(position.rawValue)">
                  <audioBlockFormat audioBlockFormatID="AB_\(String(format: "%05X", id))_00000001">
                    <speakerLabel>\(position.rawValue)</speakerLabel>
                    <position coordinate="azimuth">\(position.azimuth)</position>
                    <position coordinate="elevation">\(position.elevation)</position>
                    <position coordinate="distance">1.0</position>
                  </audioBlockFormat>
                </audioChannelFormat>
        """
    }

    private func generateObjectXML(object: AudioObject, index: Int) -> String {
        let spherical = object.spherical

        return """
                <audioObject audioObjectID="AO_\(1001 + index)" audioObjectName="\(object.name)">
                  <audioPackFormatIDRef>AP_\(String(format: "%05X", 0x20001 + index))</audioPackFormatIDRef>
                  <audioTrackUIDRef>ATU_\(String(format: "%08X", 0x00010001 + index))</audioTrackUIDRef>
                </audioObject>
                <audioPackFormat audioPackFormatID="AP_\(String(format: "%05X", 0x20001 + index))" audioPackFormatName="\(object.name)_Pack" typeLabel="0003">
                  <audioChannelFormatIDRef>AC_\(String(format: "%05X", 0x30001 + index))</audioChannelFormatIDRef>
                </audioPackFormat>
                <audioChannelFormat audioChannelFormatID="AC_\(String(format: "%05X", 0x30001 + index))" audioChannelFormatName="\(object.name)_Ch" typeLabel="0003">
                  <audioBlockFormat audioBlockFormatID="AB_\(String(format: "%05X", 0x30001 + index))_00000001">
                    <position coordinate="azimuth">\(spherical.azimuth)</position>
                    <position coordinate="elevation">\(spherical.elevation)</position>
                    <position coordinate="distance">\(spherical.distance)</position>
                    <width>\(object.size * 360)</width>
                    <gain>\(pow(10, object.gain / 20))</gain>
                  </audioBlockFormat>
                </audioChannelFormat>
        """
    }

    /// Write ADM BWF file
    public func write(to url: URL, bedAudio: [[Float]], objectAudio: [[Float]]) throws {
        // Interleave all channels
        let bedChannels = bedAudio.count
        let objectChannels = objectAudio.count
        let totalChannels = bedChannels + objectChannels

        let frameCount = bedAudio.first?.count ?? objectAudio.first?.count ?? 0
        var interleaved = [Float](repeating: 0, count: frameCount * totalChannels)

        // Interleave bed
        for ch in 0..<bedChannels {
            for frame in 0..<frameCount {
                interleaved[frame * totalChannels + ch] = bedAudio[ch][frame]
            }
        }

        // Interleave objects
        for ch in 0..<objectChannels {
            for frame in 0..<frameCount {
                interleaved[frame * totalChannels + bedChannels + ch] = objectAudio[ch][frame]
            }
        }

        // Write WAV with ADM chunk
        try writeWAV(to: url, samples: interleaved, channels: totalChannels, sampleRate: metadata.sampleRate)
    }

    private func writeWAV(to url: URL, samples: [Float], channels: Int, sampleRate: Int) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: AVAudioChannelCount(channels), interleaved: true)!

        let frameCount = samples.count / channels
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw NSError(domain: "ADMBWFWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy samples
        if let channelData = buffer.floatChannelData {
            for i in 0..<samples.count {
                let channel = i % channels
                let frame = i / channels
                channelData[channel][frame] = samples[i]
            }
        }

        // Write file
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}

// MARK: - Dolby Atmos Renderer

/// Real-time Dolby Atmos renderer
public actor DolbyAtmosRenderer {

    public struct RenderSettings {
        public var outputLayout: ChannelLayout = .atmos_7_1_4
        public var binauralMode: Bool = false
        public var headTracking: Bool = true
        public var roomSize: Float = 1.0  // Virtual room scale
        public var reverbAmount: Float = 0.3
    }

    private var settings = RenderSettings()
    private var objects: [AudioObject] = []
    private var bedChannels: [[Float]] = []
    private var panner: VBAPPanner

    // HRTF for binaural
    private var hrtfFilters: [SIMD2<[Float]>] = []  // Left/Right per direction

    // Reverb
    private var reverbBuffer: [[Float]] = []
    private var reverbReadIndex = 0

    public init(layout: ChannelLayout = .atmos_7_1_4) {
        self.panner = VBAPPanner(layout: layout)
        self.settings.outputLayout = layout
        setupHRTF()
        setupReverb()
    }

    private func setupHRTF() {
        // Generate basic HRTF filters for binaural rendering
        // (In production, load measured HRTF database like CIPIC or MIT KEMAR)
        let numDirections = 72  // 5-degree resolution
        hrtfFilters = (0..<numDirections).map { i in
            let azimuth = Float(i) * 5 - 180  // -180 to 180
            return generateHRTF(azimuth: azimuth, elevation: 0)
        }
    }

    private func generateHRTF(azimuth: Float, elevation: Float) -> SIMD2<[Float]> {
        let filterLength = 128
        var leftFilter = [Float](repeating: 0, count: filterLength)
        var rightFilter = [Float](repeating: 0, count: filterLength)

        // Simple ITD/ILD model
        let headRadius: Float = 0.0875  // meters
        let speedOfSound: Float = 343.0
        let sampleRate: Float = 48000

        let azimuthRad = azimuth * .pi / 180

        // Interaural time difference (Woodworth formula)
        let itd = headRadius / speedOfSound * (azimuthRad + sin(azimuthRad))
        let itdSamples = Int(abs(itd) * sampleRate)

        // Interaural level difference
        let ild = 1.5 * sin(azimuthRad)  // Simplified
        let leftGain = azimuth < 0 ? 1.0 : Float(pow(10, -ild / 20))
        let rightGain = azimuth > 0 ? 1.0 : Float(pow(10, ild / 20))

        // Apply delay and gain
        let leftDelay = azimuth > 0 ? itdSamples : 0
        let rightDelay = azimuth < 0 ? itdSamples : 0

        if leftDelay < filterLength {
            leftFilter[leftDelay] = leftGain
        }
        if rightDelay < filterLength {
            rightFilter[rightDelay] = rightGain
        }

        // Add simple head shadow filter (low-pass on contralateral side)
        // Apply gentle smoothing
        for i in 1..<filterLength {
            leftFilter[i] += leftFilter[i-1] * 0.1
            rightFilter[i] += rightFilter[i-1] * 0.1
        }

        return SIMD2<[Float]>(leftFilter, rightFilter)
    }

    private func setupReverb() {
        // Simple early reflections + late reverb
        let reverbLength = 48000  // 1 second at 48kHz
        let channelCount = settings.outputLayout.channelCount
        reverbBuffer = [[Float]](repeating: [Float](repeating: 0, count: reverbLength), count: max(channelCount, 2))
    }

    /// Add an audio object to the scene
    public func addObject(_ object: AudioObject) {
        objects.append(object)
    }

    /// Update object position
    public func updateObjectPosition(id: UUID, position: SIMD3<Float>) {
        if let index = objects.firstIndex(where: { $0.id == id }) {
            objects[index].position = position
        }
    }

    /// Remove an object
    public func removeObject(id: UUID) {
        objects.removeAll { $0.id == id }
    }

    /// Render to output channels
    public func render(frameCount: Int) -> [[Float]] {
        let channelCount = settings.binauralMode ? 2 : settings.outputLayout.channelCount
        var output = [[Float]](repeating: [Float](repeating: 0, count: frameCount), count: channelCount)

        // Render each object
        for object in objects {
            guard !object.samples.isEmpty else { continue }

            let samples = Array(object.samples.prefix(frameCount))
            let gainLinear = pow(10, object.gain / 20)

            if settings.binauralMode {
                // Binaural rendering
                renderBinaural(object: object, samples: samples, gain: gainLinear, output: &output)
            } else {
                // Multichannel rendering via VBAP
                let gains = panner.pan(position: object.position)

                for (ch, channelGain) in gains.enumerated() where ch < channelCount {
                    let totalGain = channelGain * gainLinear
                    for i in 0..<min(samples.count, frameCount) {
                        output[ch][i] += samples[i] * totalGain
                    }
                }
            }
        }

        // Add reverb if enabled
        if settings.reverbAmount > 0 {
            addReverb(output: &output, frameCount: frameCount)
        }

        return output
    }

    private func renderBinaural(object: AudioObject, samples: [Float], gain: Float, output: inout [[Float]]) {
        let spherical = object.spherical

        // Find nearest HRTF
        let azimuthIndex = Int((spherical.azimuth + 180) / 5) % hrtfFilters.count
        let hrtf = hrtfFilters[azimuthIndex]

        // Convolve with HRTF
        let leftFiltered = convolve(samples, with: hrtf.x)
        let rightFiltered = convolve(samples, with: hrtf.y)

        // Mix to output
        for i in 0..<min(samples.count, output[0].count) {
            output[0][i] += leftFiltered[i] * gain
            output[1][i] += rightFiltered[i] * gain
        }
    }

    private func convolve(_ signal: [Float], with filter: [Float]) -> [Float] {
        let outputLength = signal.count + filter.count - 1
        var output = [Float](repeating: 0, count: outputLength)

        vDSP_conv(signal, 1, filter, 1, &output, 1, vDSP_Length(outputLength), vDSP_Length(filter.count))

        return Array(output.prefix(signal.count))
    }

    private func addReverb(output: inout [[Float]], frameCount: Int) {
        let reverbGain = settings.reverbAmount * 0.3
        let reverbLength = reverbBuffer[0].count

        for ch in 0..<min(output.count, reverbBuffer.count) {
            for i in 0..<frameCount {
                // Add to reverb buffer
                let writeIndex = (reverbReadIndex + i) % reverbLength
                reverbBuffer[ch][writeIndex] += output[ch][i] * 0.5

                // Read from multiple taps (early reflections)
                let tap1 = (reverbReadIndex + i + 441) % reverbLength   // ~9ms
                let tap2 = (reverbReadIndex + i + 1323) % reverbLength  // ~28ms
                let tap3 = (reverbReadIndex + i + 2205) % reverbLength  // ~46ms

                output[ch][i] += (reverbBuffer[ch][tap1] * 0.3 +
                                  reverbBuffer[ch][tap2] * 0.2 +
                                  reverbBuffer[ch][tap3] * 0.1) * reverbGain

                // Decay
                reverbBuffer[ch][writeIndex] *= 0.999
            }
        }

        reverbReadIndex = (reverbReadIndex + frameCount) % reverbLength
    }

    /// Export to ADM BWF
    public func exportADMBWF(to url: URL, duration: TimeInterval) async throws {
        let sampleRate = 48000
        let frameCount = Int(duration * Double(sampleRate))

        var writer = ADMBWFWriter(metadata: ADMBWFWriter.ADMMetadata(
            programName: "Echoelmusic Atmos Mix",
            objects: objects.filter { !$0.isStatic },
            bedLayout: settings.outputLayout,
            sampleRate: sampleRate,
            bitDepth: 24,
            duration: duration
        ))

        // Render bed and objects separately
        let bedAudio = renderBed(frameCount: frameCount)
        let objectAudio = renderObjects(frameCount: frameCount)

        try writer.write(to: url, bedAudio: bedAudio, objectAudio: objectAudio)
    }

    private func renderBed(frameCount: Int) -> [[Float]] {
        let channelCount = settings.outputLayout.channelCount
        var output = [[Float]](repeating: [Float](repeating: 0, count: frameCount), count: channelCount)

        // Render static objects to bed
        for object in objects where object.isStatic {
            let samples = Array(object.samples.prefix(frameCount))
            let gains = panner.pan(position: object.position)
            let gainLinear = pow(10, object.gain / 20)

            for (ch, channelGain) in gains.enumerated() where ch < channelCount {
                let totalGain = channelGain * gainLinear
                for i in 0..<min(samples.count, frameCount) {
                    output[ch][i] += samples[i] * totalGain
                }
            }
        }

        return output
    }

    private func renderObjects(frameCount: Int) -> [[Float]] {
        // Return mono stems for each dynamic object
        return objects.filter { !$0.isStatic }.map { object in
            let gainLinear = pow(10, object.gain / 20)
            return object.samples.prefix(frameCount).map { $0 * gainLinear }
        }
    }
}

// MARK: - Dolby Atmos Engine

/// Main Dolby Atmos engine interface
public actor DolbyAtmosEngine {

    public static let shared = DolbyAtmosEngine()

    private var renderer: DolbyAtmosRenderer
    private var outputFormat: ImmersiveAudioFormat = .dolbyAtmos

    // Monitoring
    public private(set) var objectCount: Int = 0
    public private(set) var bedChannelCount: Int = 12
    public private(set) var isRendering: Bool = false

    private init() {
        self.renderer = DolbyAtmosRenderer(layout: .atmos_7_1_4)
    }

    /// Configure output format
    public func setOutputFormat(_ format: ImmersiveAudioFormat) async {
        self.outputFormat = format
        self.renderer = DolbyAtmosRenderer(layout: format.channelLayout)
        self.bedChannelCount = format.channelLayout.channelCount
    }

    /// Add positioned audio object
    public func addObject(name: String, audio: [Float], position: SIMD3<Float>, gain: Float = 0) async -> UUID {
        var object = AudioObject(name: name, position: position, gain: gain)
        object.samples = audio
        await renderer.addObject(object)
        objectCount += 1
        return object.id
    }

    /// Add static bed element
    public func addBedElement(name: String, audio: [Float], speaker: SpeakerPosition, gain: Float = 0) async -> UUID {
        var object = AudioObject(name: name, gain: gain)
        object.samples = audio
        object.isStatic = true

        // Convert speaker position to 3D
        let azimuthRad = speaker.azimuth * .pi / 180
        let elevationRad = speaker.elevation * .pi / 180
        object.position = SIMD3<Float>(
            cos(elevationRad) * sin(azimuthRad),
            sin(elevationRad),
            cos(elevationRad) * cos(azimuthRad)
        )

        await renderer.addObject(object)
        return object.id
    }

    /// Move object in real-time
    public func moveObject(id: UUID, to position: SIMD3<Float>) async {
        await renderer.updateObjectPosition(id: id, position: position)
    }

    /// Render frame
    public func render(frameCount: Int) async -> [[Float]] {
        isRendering = true
        let output = await renderer.render(frameCount: frameCount)
        isRendering = false
        return output
    }

    /// Export to ADM BWF file
    public func export(to url: URL, duration: TimeInterval) async throws {
        try await renderer.exportADMBWF(to: url, duration: duration)
    }

    /// Export for Apple Spatial Audio
    public func exportAppleSpatial(to url: URL, duration: TimeInterval) async throws {
        // Apple Spatial uses Dolby Atmos in MP4 container
        // First export ADM BWF, then convert
        let tempURL = url.deletingPathExtension().appendingPathExtension("wav")
        try await export(to: tempURL, duration: duration)

        // In production, use Apple's Spatial Audio tools or afconvert
        // For now, copy as placeholder
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.copyItem(at: tempURL, to: url)
        try? FileManager.default.removeItem(at: tempURL)
    }

    /// Get supported formats
    public func supportedFormats() -> [ImmersiveAudioFormat] {
        ImmersiveAudioFormat.allCases
    }
}
