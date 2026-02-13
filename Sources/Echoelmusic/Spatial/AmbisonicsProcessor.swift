import Foundation
import Accelerate

/// First and Higher Order Ambisonics (FOA/HOA) encoder and decoder.
///
/// Encodes spatial audio sources into Ambisonics B-format and decodes
/// to arbitrary speaker layouts or binaural output.
///
/// B-Format Channels (ACN ordering, SN3D normalization):
/// - FOA (1st Order): W, Y, Z, X (4 channels)
/// - SOA (2nd Order): + V, T, R, S, U (9 channels total)
/// - TOA (3rd Order): + Q, O, M, K, L, N, P (16 channels total)
///
/// Coordinate System: right-handed (X forward, Y left, Z up)
class AmbisonicsProcessor {

    // MARK: - Types

    enum AmbisonicsOrder: Int, CaseIterable {
        case first = 1    // 4 channels (W, Y, Z, X)
        case second = 2   // 9 channels
        case third = 3    // 16 channels

        var channelCount: Int {
            (rawValue + 1) * (rawValue + 1)
        }
    }

    enum DecoderLayout: String, CaseIterable {
        case stereo         // 2 speakers
        case quad           // 4 speakers (square)
        case surround5_1    // 5.1 surround
        case surround7_1    // 7.1 surround
        case octahedron     // 6 speakers (3D)
        case dome           // 8+ speakers (hemisphere)
        case binaural       // Headphone decode via virtual speakers

        var speakerPositions: [(azimuth: Float, elevation: Float)] {
            switch self {
            case .stereo:
                return [(-30, 0), (30, 0)]
            case .quad:
                return [(-45, 0), (45, 0), (-135, 0), (135, 0)]
            case .surround5_1:
                return [(0, 0), (-30, 0), (30, 0), (-110, 0), (110, 0), (0, 0)] // C, L, R, Ls, Rs, LFE
            case .surround7_1:
                return [(0, 0), (-30, 0), (30, 0), (-90, 0), (90, 0), (-135, 0), (135, 0), (0, 0)]
            case .octahedron:
                return [(0, 0), (90, 0), (180, 0), (270, 0), (0, 90), (0, -90)]
            case .dome:
                return [(0, 0), (45, 0), (90, 0), (135, 0), (180, 0), (225, 0), (270, 0), (315, 0),
                        (0, 45), (90, 45), (180, 45), (270, 45), (0, 90)]
            case .binaural:
                // Virtual speakers for binaural decode (8 virtual sources)
                return [(0, 0), (45, 0), (90, 0), (135, 0), (180, 0), (225, 0), (270, 0), (315, 0)]
            }
        }
    }

    struct Configuration {
        var order: AmbisonicsOrder = .first
        var decoderLayout: DecoderLayout = .binaural
        var nearFieldCompensation: Bool = false
        var maxReGain: Bool = true  // Apply max-rE weighting for improved localization

        static let `default` = Configuration()
        static let highQuality = Configuration(order: .third, decoderLayout: .binaural, maxReGain: true)
        static let surround = Configuration(order: .first, decoderLayout: .surround5_1)
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double

    /// B-format buffer: [channel][sample]
    private var bFormatBuffer: [[Float]]

    /// Decoder matrix: [speaker][ambisonics_channel]
    private var decoderMatrix: [[Float]]

    // MARK: - Initialization

    init(sampleRate: Double = 48000, configuration: Configuration = .default) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        self.bFormatBuffer = []
        self.decoderMatrix = []
        computeDecoderMatrix()
    }

    // MARK: - Encoding

    /// Encode a mono source into B-format at the given position.
    ///
    /// - Parameters:
    ///   - input: Mono audio buffer
    ///   - azimuth: Horizontal angle in degrees (0 = front, 90 = left, -90 = right)
    ///   - elevation: Vertical angle in degrees (0 = horizon, 90 = zenith, -90 = nadir)
    ///   - distance: Distance in meters (for near-field compensation)
    /// - Returns: B-format channels array [W, Y, Z, X, ...] with SN3D normalization
    func encode(_ input: [Float], azimuth: Float, elevation: Float, distance: Float = 1.0) -> [[Float]] {
        let channelCount = configuration.order.channelCount
        let sampleCount = input.count

        let azRad = azimuth * .pi / 180.0
        let elRad = elevation * .pi / 180.0

        // Compute spherical harmonic coefficients (SN3D, ACN ordering)
        let coefficients = computeSHCoefficients(azimuth: azRad, elevation: elRad)

        var bFormat = [[Float]](repeating: [Float](repeating: 0, count: sampleCount), count: channelCount)

        // Encode: each B-format channel = input * SH coefficient
        for ch in 0..<min(channelCount, coefficients.count) {
            let coeff = coefficients[ch]
            vDSP_vsma(input, 1, [coeff], bFormat[ch], 1, &bFormat[ch], 1, vDSP_Length(sampleCount))
        }

        // Near-field compensation (distance attenuation for W channel)
        if configuration.nearFieldCompensation && distance > 0.01 {
            let distGain = 1.0 / max(distance, 0.1)
            vDSP_vsmul(bFormat[0], 1, [distGain], &bFormat[0], 1, vDSP_Length(sampleCount))
        }

        return bFormat
    }

    /// Encode a source from SIMD3 position (Cartesian coordinates).
    func encode(_ input: [Float], position: SIMD3<Float>) -> [[Float]] {
        let distance = simd_length(position)
        guard distance > 0.001 else {
            return encode(input, azimuth: 0, elevation: 0, distance: 0)
        }

        let azimuth = atan2(position.y, position.x) * 180.0 / .pi
        let elevation = asin(position.z / distance) * 180.0 / .pi
        return encode(input, azimuth: azimuth, elevation: elevation, distance: distance)
    }

    // MARK: - Accumulation

    /// Accumulate a source into the internal B-format buffer (for mixing multiple sources).
    func accumulateSource(_ input: [Float], azimuth: Float, elevation: Float, distance: Float = 1.0) {
        let encoded = encode(input, azimuth: azimuth, elevation: elevation, distance: distance)

        if bFormatBuffer.isEmpty || bFormatBuffer[0].count != input.count {
            bFormatBuffer = encoded.map { [Float](repeating: 0, count: $0.count) }
        }

        for ch in 0..<min(encoded.count, bFormatBuffer.count) {
            vDSP_vadd(bFormatBuffer[ch], 1, encoded[ch], 1, &bFormatBuffer[ch], 1, vDSP_Length(input.count))
        }
    }

    /// Clear the accumulated B-format buffer.
    func clearAccumulator() {
        bFormatBuffer = []
    }

    // MARK: - Decoding

    /// Decode B-format to speaker feeds.
    ///
    /// - Parameter bFormat: B-format channels [W, Y, Z, X, ...]
    /// - Returns: Speaker feeds array [speaker0, speaker1, ...]
    func decode(_ bFormat: [[Float]]) -> [[Float]] {
        guard !bFormat.isEmpty, !bFormat[0].isEmpty else { return [] }

        let speakerCount = configuration.decoderLayout.speakerPositions.count
        let sampleCount = bFormat[0].count
        let channelCount = min(bFormat.count, configuration.order.channelCount)

        var speakerFeeds = [[Float]](repeating: [Float](repeating: 0, count: sampleCount), count: speakerCount)

        // Matrix decode: speaker[s] = sum( decoderMatrix[s][ch] * bFormat[ch] )
        for s in 0..<speakerCount {
            for ch in 0..<channelCount {
                guard s < decoderMatrix.count, ch < decoderMatrix[s].count else { continue }
                let gain = decoderMatrix[s][ch]
                guard abs(gain) > 0.0001 else { continue }
                vDSP_vsma(bFormat[ch], 1, [gain], speakerFeeds[s], 1, &speakerFeeds[s], 1, vDSP_Length(sampleCount))
            }
        }

        return speakerFeeds
    }

    /// Decode the accumulated B-format buffer to speaker feeds.
    func decodeAccumulated() -> [[Float]] {
        return decode(bFormatBuffer)
    }

    /// Decode B-format to stereo (binaural or downmix).
    func decodeToStereo(_ bFormat: [[Float]]) -> (left: [Float], right: [Float]) {
        guard bFormat.count >= 4, !bFormat[0].isEmpty else {
            let empty = [Float](repeating: 0, count: bFormat.first?.count ?? 0)
            return (empty, empty)
        }

        let sampleCount = bFormat[0].count
        var left = [Float](repeating: 0, count: sampleCount)
        var right = [Float](repeating: 0, count: sampleCount)

        let w = bFormat[0] // Omnidirectional (pressure)
        let y = bFormat[1] // Left-Right (Y axis)
        let x = bFormat[3] // Front-Back (X axis)

        // Simple stereo decode: L = 0.5*W + 0.5*Y + 0.35*X, R = 0.5*W - 0.5*Y + 0.35*X
        let wGain: Float = 0.5
        let yGain: Float = 0.5
        let xGain: Float = 0.35

        // Left = wGain*W + yGain*Y + xGain*X
        vDSP_vsma(w, 1, [wGain], left, 1, &left, 1, vDSP_Length(sampleCount))
        vDSP_vsma(y, 1, [yGain], left, 1, &left, 1, vDSP_Length(sampleCount))
        vDSP_vsma(x, 1, [xGain], left, 1, &left, 1, vDSP_Length(sampleCount))

        // Right = wGain*W - yGain*Y + xGain*X
        vDSP_vsma(w, 1, [wGain], right, 1, &right, 1, vDSP_Length(sampleCount))
        var negYGain = -yGain
        vDSP_vsma(y, 1, [negYGain], right, 1, &right, 1, vDSP_Length(sampleCount))
        vDSP_vsma(x, 1, [xGain], right, 1, &right, 1, vDSP_Length(sampleCount))

        return (left, right)
    }

    // MARK: - B-Format Rotation

    /// Rotate the B-format sound field (for head tracking).
    ///
    /// - Parameters:
    ///   - bFormat: B-format channels
    ///   - yaw: Rotation around Z axis (degrees)
    ///   - pitch: Rotation around Y axis (degrees)
    ///   - roll: Rotation around X axis (degrees)
    /// - Returns: Rotated B-format channels
    func rotateBFormat(_ bFormat: [[Float]], yaw: Float, pitch: Float, roll: Float) -> [[Float]] {
        guard bFormat.count >= 4, !bFormat[0].isEmpty else { return bFormat }

        let sampleCount = bFormat[0].count
        let yawRad = yaw * .pi / 180.0
        let pitchRad = pitch * .pi / 180.0

        var rotated = bFormat

        // W channel (0) is omnidirectional - unaffected by rotation
        // For FOA, rotate X, Y, Z channels
        let cosYaw = cos(yawRad)
        let sinYaw = sin(yawRad)
        let cosPitch = cos(pitchRad)
        let sinPitch = sin(pitchRad)

        let origY = bFormat[1] // Y
        let origZ = bFormat[2] // Z
        let origX = bFormat[3] // X

        var newX = [Float](repeating: 0, count: sampleCount)
        var newY = [Float](repeating: 0, count: sampleCount)
        var newZ = [Float](repeating: 0, count: sampleCount)

        // Yaw rotation (around Z): X' = X*cos - Y*sin, Y' = X*sin + Y*cos
        // Pitch rotation (around Y): X' = X*cos + Z*sin, Z' = -X*sin + Z*cos
        for i in 0..<sampleCount {
            // Apply yaw
            let xAfterYaw = origX[i] * cosYaw - origY[i] * sinYaw
            let yAfterYaw = origX[i] * sinYaw + origY[i] * cosYaw

            // Apply pitch
            newX[i] = xAfterYaw * cosPitch + origZ[i] * sinPitch
            newZ[i] = -xAfterYaw * sinPitch + origZ[i] * cosPitch
            newY[i] = yAfterYaw
        }

        rotated[1] = newY
        rotated[2] = newZ
        rotated[3] = newX

        return rotated
    }

    // MARK: - Spherical Harmonics

    /// Compute SN3D-normalized spherical harmonic coefficients up to configured order.
    private func computeSHCoefficients(azimuth: Float, elevation: Float) -> [Float] {
        let cosEl = cos(elevation)
        let sinEl = sin(elevation)
        let cosAz = cos(azimuth)
        let sinAz = sin(azimuth)

        var coefficients: [Float] = []

        // Order 0 (1 channel): W
        coefficients.append(1.0) // Y_0^0 = 1 (SN3D)

        guard configuration.order.rawValue >= 1 else { return coefficients }

        // Order 1 (3 channels): Y, Z, X (ACN 1, 2, 3)
        coefficients.append(cosEl * sinAz)   // Y_1^-1 = Y
        coefficients.append(sinEl)            // Y_1^0  = Z
        coefficients.append(cosEl * cosAz)    // Y_1^1  = X

        guard configuration.order.rawValue >= 2 else { return coefficients }

        // Order 2 (5 channels): V, T, R, S, U (ACN 4-8)
        let cos2Az = cos(2.0 * azimuth)
        let sin2Az = sin(2.0 * azimuth)
        let sin2El = sin(2.0 * elevation)

        coefficients.append(sqrt(3.0 / 4.0) * cosEl * cosEl * sin2Az)        // V: Y_2^-2
        coefficients.append(sqrt(3.0 / 4.0) * sin2El * sinAz)                 // T: Y_2^-1
        coefficients.append(0.5 * (3.0 * sinEl * sinEl - 1.0))                // R: Y_2^0
        coefficients.append(sqrt(3.0 / 4.0) * sin2El * cosAz)                 // S: Y_2^1
        coefficients.append(sqrt(3.0 / 4.0) * cosEl * cosEl * cos2Az)        // U: Y_2^2

        guard configuration.order.rawValue >= 3 else { return coefficients }

        // Order 3 (7 channels): Q, O, M, K, L, N, P (ACN 9-15)
        let cos3Az = cos(3.0 * azimuth)
        let sin3Az = sin(3.0 * azimuth)
        let cosEl2 = cosEl * cosEl
        let cosEl3 = cosEl2 * cosEl

        coefficients.append(sqrt(5.0 / 8.0) * cosEl3 * sin3Az)                              // Q: Y_3^-3
        coefficients.append(sqrt(15.0 / 4.0) * sinEl * cosEl2 * sin2Az)                      // O: Y_3^-2
        coefficients.append(sqrt(3.0 / 8.0) * cosEl * (5.0 * sinEl * sinEl - 1.0) * sinAz)  // M: Y_3^-1
        coefficients.append(0.5 * sinEl * (5.0 * sinEl * sinEl - 3.0))                       // K: Y_3^0
        coefficients.append(sqrt(3.0 / 8.0) * cosEl * (5.0 * sinEl * sinEl - 1.0) * cosAz)  // L: Y_3^1
        coefficients.append(sqrt(15.0 / 4.0) * sinEl * cosEl2 * cos2Az)                      // N: Y_3^2
        coefficients.append(sqrt(5.0 / 8.0) * cosEl3 * cos3Az)                               // P: Y_3^3

        return coefficients
    }

    // MARK: - Decoder Matrix

    /// Compute the decode matrix for the current configuration.
    private func computeDecoderMatrix() {
        let positions = configuration.decoderLayout.speakerPositions
        let channelCount = configuration.order.channelCount
        let speakerCount = positions.count

        decoderMatrix = [[Float]](repeating: [Float](repeating: 0, count: channelCount), count: speakerCount)

        for (s, pos) in positions.enumerated() {
            let azRad = pos.azimuth * .pi / 180.0
            let elRad = pos.elevation * .pi / 180.0
            let coeffs = computeSHCoefficients(azimuth: azRad, elevation: elRad)

            for ch in 0..<min(channelCount, coeffs.count) {
                var gain = coeffs[ch]

                // Apply max-rE weighting for improved localization
                if configuration.maxReGain {
                    gain *= maxReWeight(order: configuration.order.rawValue, channel: ch)
                }

                decoderMatrix[s][ch] = gain / Float(speakerCount)
            }
        }
    }

    /// Max-rE weights for improved localization (energy vector optimization).
    private func maxReWeight(order: Int, channel: Int) -> Float {
        // Compute the order of the given ACN channel
        let l = Int(sqrt(Float(channel)))

        switch order {
        case 1:
            // FOA max-rE weights
            return l == 0 ? 1.0 : 0.5774
        case 2:
            // SOA max-rE weights
            let weights: [Float] = [1.0, 0.7746, 0.4472]
            return l < weights.count ? weights[l] : 0.3
        case 3:
            // TOA max-rE weights
            let weights: [Float] = [1.0, 0.8611, 0.6124, 0.3536]
            return l < weights.count ? weights[l] : 0.25
        default:
            return 1.0
        }
    }

    /// Update decoder matrix when configuration changes.
    func updateConfiguration(_ newConfig: Configuration) {
        configuration = newConfig
        computeDecoderMatrix()
    }

    // MARK: - Reset

    func reset() {
        bFormatBuffer = []
    }
}
