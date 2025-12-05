import Foundation
import Accelerate
import simd

/// SIMD-Optimized Spatial Audio Processor
/// High-performance 3D/4D audio positioning using Apple's Accelerate & simd frameworks
/// Supports: Head Tracking, HRTF, Ambisonics, 4D Orbital Motion
final class SIMDSpatialProcessor {

    // MARK: - Configuration

    struct Configuration {
        var maxSources: Int = 128
        var updateRate: Double = 60.0  // Hz
        var interpolationSteps: Int = 16
        var speedOfSound: Float = 343.0  // m/s
    }

    private var config: Configuration
    private let processingQueue = DispatchQueue(label: "spatial.simd.processing", qos: .userInteractive)

    // MARK: - Source State (Structure of Arrays for SIMD)

    // Position arrays
    private var positionsX: [Float] = []
    private var positionsY: [Float] = []
    private var positionsZ: [Float] = []

    // Velocity arrays
    private var velocitiesX: [Float] = []
    private var velocitiesY: [Float] = []
    private var velocitiesZ: [Float] = []

    // Orbital parameters
    private var orbitalRadii: [Float] = []
    private var orbitalSpeeds: [Float] = []
    private var orbitalPhases: [Float] = []
    private var orbitalAxes: [simd_float3] = []  // Rotation axis for 3D orbits

    // Source properties
    private var amplitudes: [Float] = []
    private var distances: [Float] = []
    private var azimuths: [Float] = []
    private var elevations: [Float] = []

    // Interpolation state
    private var targetPositionsX: [Float] = []
    private var targetPositionsY: [Float] = []
    private var targetPositionsZ: [Float] = []

    // MARK: - Listener State

    private var listenerPosition: simd_float3 = .zero
    private var listenerOrientation: simd_quatf = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
    private var listenerVelocity: simd_float3 = .zero

    // MARK: - HRTF Convolution

    private var hrtfFiltersLeft: [[Float]] = []
    private var hrtfFiltersRight: [[Float]] = []
    private let hrtfFilterLength: Int = 128

    // MARK: - Initialization

    init(config: Configuration = Configuration()) {
        self.config = config
        allocateBuffers()
        loadHRTFData()
    }

    private func allocateBuffers() {
        let n = config.maxSources

        positionsX = [Float](repeating: 0, count: n)
        positionsY = [Float](repeating: 0, count: n)
        positionsZ = [Float](repeating: 0, count: n)

        velocitiesX = [Float](repeating: 0, count: n)
        velocitiesY = [Float](repeating: 0, count: n)
        velocitiesZ = [Float](repeating: 0, count: n)

        orbitalRadii = [Float](repeating: 0, count: n)
        orbitalSpeeds = [Float](repeating: 0, count: n)
        orbitalPhases = [Float](repeating: 0, count: n)
        orbitalAxes = [simd_float3](repeating: simd_float3(0, 1, 0), count: n)

        amplitudes = [Float](repeating: 1, count: n)
        distances = [Float](repeating: 1, count: n)
        azimuths = [Float](repeating: 0, count: n)
        elevations = [Float](repeating: 0, count: n)

        targetPositionsX = [Float](repeating: 0, count: n)
        targetPositionsY = [Float](repeating: 0, count: n)
        targetPositionsZ = [Float](repeating: 0, count: n)
    }

    private func loadHRTFData() {
        // Generate HRTF impulse responses based on spherical head model
        // Models interaural time difference (ITD) and interaural level difference (ILD)
        let azimuthSteps = 72  // 5° resolution
        let elevationSteps = 18  // 10° resolution
        let sampleRate: Float = 48000
        let headRadius: Float = 0.0875  // meters (average human head)
        let speedOfSound: Float = 343.0  // m/s

        for elevationIndex in 0..<elevationSteps {
            let elevation = Float(elevationIndex - 9) * 10.0 * Float.pi / 180.0  // -90° to +80°

            for azimuthIndex in 0..<azimuthSteps {
                let azimuth = Float(azimuthIndex) * 5.0 * Float.pi / 180.0  // 0° to 355°

                var filterL = [Float](repeating: 0, count: hrtfFilterLength)
                var filterR = [Float](repeating: 0, count: hrtfFilterLength)

                // Calculate ITD (Woodworth formula)
                let itd = headRadius / speedOfSound * (azimuth + sin(azimuth))
                let itdSamples = Int(abs(itd) * sampleRate)

                // Calculate ILD (frequency-dependent, simplified)
                let ildLeft = azimuth > 0 ? 1.0 - 0.3 * sin(azimuth) : 1.0
                let ildRight = azimuth < 0 ? 1.0 - 0.3 * sin(-azimuth) : 1.0

                // Generate minimum-phase HRIR approximation
                // Using exponential decay with head shadow
                let decayRate: Float = 0.85
                let headShadowL = max(0.3, cos(azimuth / 2))
                let headShadowR = max(0.3, cos((Float.pi - azimuth) / 2))

                // Left ear filter
                let delayL = azimuth < 0 ? itdSamples : 0
                for i in delayL..<hrtfFilterLength {
                    let t = Float(i - delayL)
                    // Impulse response: attack + exponential decay
                    let envelope = exp(-t * (1.0 - decayRate) * 0.1)
                    // Add high-frequency rolloff for head shadow
                    let hfRolloff = 1.0 - 0.3 * sin(Float.pi * t / Float(hrtfFilterLength))
                    filterL[i] = Float(ildLeft) * headShadowL * envelope * hfRolloff
                    if i == delayL { filterL[i] *= 2.0 }  // Initial impulse
                }

                // Right ear filter
                let delayR = azimuth > 0 ? itdSamples : 0
                for i in delayR..<hrtfFilterLength {
                    let t = Float(i - delayR)
                    let envelope = exp(-t * (1.0 - decayRate) * 0.1)
                    let hfRolloff = 1.0 - 0.3 * sin(Float.pi * t / Float(hrtfFilterLength))
                    filterR[i] = Float(ildRight) * headShadowR * envelope * hfRolloff
                    if i == delayR { filterR[i] *= 2.0 }
                }

                // Apply elevation-dependent pinna filtering (notch around 8kHz)
                let pinnaNotchFreq = 8000.0 + Float(elevation) * 1000.0
                let pinnaNotchWidth = 2000.0
                for i in 0..<hrtfFilterLength {
                    let freq = Float(i) * sampleRate / Float(hrtfFilterLength * 2)
                    let notchFactor = 1.0 - 0.3 * exp(-pow((freq - pinnaNotchFreq) / pinnaNotchWidth, 2))
                    filterL[i] *= notchFactor
                    filterR[i] *= notchFactor
                }

                // Normalize filters
                let maxL = filterL.max() ?? 1.0
                let maxR = filterR.max() ?? 1.0
                if maxL > 0 { filterL = filterL.map { $0 / maxL } }
                if maxR > 0 { filterR = filterR.map { $0 / maxR } }

                hrtfFiltersLeft.append(filterL)
                hrtfFiltersRight.append(filterR)
            }
        }
    }

    // MARK: - SIMD 4D Orbital Update

    /// Update all orbital positions using SIMD (batch processing)
    func update4DOrbitalMotion(sourceCount: Int, deltaTime: Float) {
        guard sourceCount > 0 else { return }

        let n = vDSP_Length(sourceCount)

        // Update phases: phase += speed * deltaTime
        var dt = deltaTime
        vDSP_vsma(orbitalSpeeds, 1, &dt, orbitalPhases, 1, &orbitalPhases, 1, n)

        // Wrap phases to [0, 2π]
        var twoPi = Float.pi * 2
        vDSP_vfrac(orbitalPhases, 1, &orbitalPhases, 1, n)  // Get fractional part
        vDSP_vsmul(orbitalPhases, 1, &twoPi, &orbitalPhases, 1, n)  // Scale to 2π

        // Calculate new positions using cos/sin
        // x = radius * cos(phase)
        // y = radius * sin(phase)

        // Compute cos(phase) and sin(phase) for all sources
        var cosPhases = [Float](repeating: 0, count: sourceCount)
        var sinPhases = [Float](repeating: 0, count: sourceCount)

        // Vectorized trigonometry
        var count = Int32(sourceCount)
        vvcosf(&cosPhases, orbitalPhases, &count)
        vvsinf(&sinPhases, orbitalPhases, &count)

        // x = radius * cos(phase) [for sources with radius > 0]
        // y = radius * sin(phase)
        vDSP_vmul(orbitalRadii, 1, cosPhases, 1, &positionsX, 1, n)
        vDSP_vmul(orbitalRadii, 1, sinPhases, 1, &positionsY, 1, n)

        // For 3D orbits, apply rotation around orbital axis
        for i in 0..<sourceCount where orbitalRadii[i] > 0 {
            let axis = orbitalAxes[i]
            if axis != simd_float3(0, 1, 0) {
                // Rotate position around custom axis
                let rotation = simd_quatf(angle: orbitalPhases[i], axis: normalize(axis))
                let basePos = simd_float3(orbitalRadii[i], 0, 0)
                let rotatedPos = rotation.act(basePos)

                positionsX[i] = rotatedPos.x
                positionsY[i] = rotatedPos.y
                positionsZ[i] = rotatedPos.z
            }
        }
    }

    // MARK: - SIMD Position Interpolation

    /// Smoothly interpolate positions to targets using SIMD
    func interpolatePositions(sourceCount: Int, factor: Float) {
        guard sourceCount > 0 else { return }

        let n = vDSP_Length(sourceCount)
        var alpha = factor
        var oneMinusAlpha = 1.0 - factor

        // position = position * (1 - alpha) + target * alpha
        // Using vDSP_vintb for interpolation

        vDSP_vintb(positionsX, 1, targetPositionsX, 1, &alpha, &positionsX, 1, n)
        vDSP_vintb(positionsY, 1, targetPositionsY, 1, &alpha, &positionsY, 1, n)
        vDSP_vintb(positionsZ, 1, targetPositionsZ, 1, &alpha, &positionsZ, 1, n)
    }

    // MARK: - SIMD Distance & Angle Calculation

    /// Calculate distances from listener to all sources using SIMD
    func calculateDistances(sourceCount: Int) {
        guard sourceCount > 0 else { return }

        let n = vDSP_Length(sourceCount)

        // Calculate relative positions
        var relX = [Float](repeating: 0, count: sourceCount)
        var relY = [Float](repeating: 0, count: sourceCount)
        var relZ = [Float](repeating: 0, count: sourceCount)

        // rel = pos - listener
        var negListenerX = -listenerPosition.x
        var negListenerY = -listenerPosition.y
        var negListenerZ = -listenerPosition.z

        vDSP_vsadd(positionsX, 1, &negListenerX, &relX, 1, n)
        vDSP_vsadd(positionsY, 1, &negListenerY, &relY, 1, n)
        vDSP_vsadd(positionsZ, 1, &negListenerZ, &relZ, 1, n)

        // Calculate squared distances
        var sqX = [Float](repeating: 0, count: sourceCount)
        var sqY = [Float](repeating: 0, count: sourceCount)
        var sqZ = [Float](repeating: 0, count: sourceCount)

        vDSP_vsq(relX, 1, &sqX, 1, n)
        vDSP_vsq(relY, 1, &sqY, 1, n)
        vDSP_vsq(relZ, 1, &sqZ, 1, n)

        // Sum squared components
        var sumSq = [Float](repeating: 0, count: sourceCount)
        vDSP_vadd(sqX, 1, sqY, 1, &sumSq, 1, n)
        vDSP_vadd(sumSq, 1, sqZ, 1, &sumSq, 1, n)

        // Square root for distances
        var count = Int32(sourceCount)
        vvsqrtf(&distances, sumSq, &count)

        // Calculate azimuths: atan2(relX, relZ)
        vvatan2f(&azimuths, relX, relZ, &count)

        // Calculate elevations: asin(relY / distance)
        var normalizedY = [Float](repeating: 0, count: sourceCount)
        vDSP_vdiv(distances, 1, relY, 1, &normalizedY, 1, n)

        // Clamp to [-1, 1] before asin
        var minOne: Float = -1.0
        var one: Float = 1.0
        vDSP_vclip(normalizedY, 1, &minOne, &one, &normalizedY, 1, n)

        vvasinf(&elevations, normalizedY, &count)
    }

    // MARK: - SIMD Distance Attenuation

    /// Calculate amplitude attenuation based on distance
    func calculateAttenuation(sourceCount: Int, referenceDistance: Float = 1.0, maxDistance: Float = 100.0) {
        guard sourceCount > 0 else { return }

        let n = vDSP_Length(sourceCount)

        // Inverse distance attenuation: gain = ref / max(distance, ref)
        var clampedDistances = [Float](repeating: 0, count: sourceCount)
        var refDist = referenceDistance

        // Clamp distances to minimum of reference distance
        vDSP_vmax(distances, 1, [Float](repeating: referenceDistance, count: sourceCount), 1, &clampedDistances, 1, n)

        // gain = referenceDistance / clampedDistance
        vDSP_svdiv(&refDist, clampedDistances, 1, &amplitudes, 1, n)

        // Clamp to [0, 1]
        var zero: Float = 0
        var one: Float = 1
        vDSP_vclip(amplitudes, 1, &zero, &one, &amplitudes, 1, n)
    }

    // MARK: - SIMD Doppler Effect

    /// Calculate Doppler frequency shift for all sources
    func calculateDopplerShift(sourceCount: Int, baseFrequencies: [Float]) -> [Float] {
        guard sourceCount > 0 else { return [] }

        var shiftedFrequencies = [Float](repeating: 0, count: sourceCount)
        let c = config.speedOfSound

        for i in 0..<sourceCount {
            // Calculate relative velocity along source-listener axis
            let sourcePos = simd_float3(positionsX[i], positionsY[i], positionsZ[i])
            let sourceVel = simd_float3(velocitiesX[i], velocitiesY[i], velocitiesZ[i])

            let direction = normalize(sourcePos - listenerPosition)
            let relativeVelocity = dot(sourceVel - listenerVelocity, direction)

            // Doppler formula: f' = f * c / (c + vr)
            let dopplerFactor = c / (c + relativeVelocity)
            shiftedFrequencies[i] = baseFrequencies[i] * dopplerFactor
        }

        return shiftedFrequencies
    }

    // MARK: - SIMD Panning (Stereo)

    /// Calculate stereo panning coefficients for all sources
    func calculateStereoPanning(sourceCount: Int) -> (left: [Float], right: [Float]) {
        guard sourceCount > 0 else { return ([], []) }

        var leftGains = [Float](repeating: 0, count: sourceCount)
        var rightGains = [Float](repeating: 0, count: sourceCount)

        let n = vDSP_Length(sourceCount)

        // Pan law: constant power panning
        // left = cos(azimuth * 0.5 + π/4)
        // right = sin(azimuth * 0.5 + π/4)

        var scaledAzimuths = [Float](repeating: 0, count: sourceCount)
        var quarterPi = Float.pi / 4
        var half: Float = 0.5

        // scale azimuth and add offset
        vDSP_vsmsa(azimuths, 1, &half, &quarterPi, &scaledAzimuths, 1, n)

        // Calculate cos and sin
        var count = Int32(sourceCount)
        vvcosf(&leftGains, scaledAzimuths, &count)
        vvsinf(&rightGains, scaledAzimuths, &count)

        // Apply distance attenuation
        vDSP_vmul(leftGains, 1, amplitudes, 1, &leftGains, 1, n)
        vDSP_vmul(rightGains, 1, amplitudes, 1, &rightGains, 1, n)

        return (leftGains, rightGains)
    }

    // MARK: - SIMD HRTF Processing

    /// Apply HRTF convolution for binaural audio
    func processHRTF(
        monoInput: [Float],
        sourceIndex: Int
    ) -> (left: [Float], right: [Float]) {
        let azimuth = azimuths[sourceIndex]
        let elevation = elevations[sourceIndex]

        // Get HRTF filter index from azimuth/elevation
        let hrtfIndex = getHRTFIndex(azimuth: azimuth, elevation: elevation)

        guard hrtfIndex < hrtfFiltersLeft.count else {
            return (monoInput, monoInput)
        }

        let filterL = hrtfFiltersLeft[hrtfIndex]
        let filterR = hrtfFiltersRight[hrtfIndex]

        // Convolve input with HRTF filters
        let outputLength = monoInput.count + hrtfFilterLength - 1
        var outputL = [Float](repeating: 0, count: outputLength)
        var outputR = [Float](repeating: 0, count: outputLength)

        vDSP_conv(monoInput, 1, filterL, 1, &outputL, 1, vDSP_Length(outputLength), vDSP_Length(hrtfFilterLength))
        vDSP_conv(monoInput, 1, filterR, 1, &outputR, 1, vDSP_Length(outputLength), vDSP_Length(hrtfFilterLength))

        // Trim to original length
        let trimmedL = Array(outputL.prefix(monoInput.count))
        let trimmedR = Array(outputR.prefix(monoInput.count))

        // Apply distance attenuation
        var amplitude = amplitudes[sourceIndex]
        var attenuatedL = [Float](repeating: 0, count: trimmedL.count)
        var attenuatedR = [Float](repeating: 0, count: trimmedR.count)

        vDSP_vsmul(trimmedL, 1, &amplitude, &attenuatedL, 1, vDSP_Length(trimmedL.count))
        vDSP_vsmul(trimmedR, 1, &amplitude, &attenuatedR, 1, vDSP_Length(trimmedR.count))

        return (attenuatedL, attenuatedR)
    }

    private func getHRTFIndex(azimuth: Float, elevation: Float) -> Int {
        // Convert azimuth/elevation to HRTF database index
        let azimuthDeg = azimuth * 180 / Float.pi
        let elevationDeg = elevation * 180 / Float.pi

        let azimuthStep = Int((azimuthDeg + 180) / 5) % 72  // 5° resolution
        let elevationStep = Int((elevationDeg + 90) / 10) % 18  // 10° resolution

        return azimuthStep * 18 + elevationStep
    }

    // MARK: - SIMD Ambisonics Encoding

    /// Encode mono sources to first-order ambisonics (B-format)
    func encodeAmbisonics(sourceCount: Int, monoInputs: [[Float]]) -> AmbisonicsFrame {
        guard sourceCount > 0, !monoInputs.isEmpty else {
            return AmbisonicsFrame(w: [], x: [], y: [], z: [])
        }

        let frameLength = monoInputs[0].count
        var w = [Float](repeating: 0, count: frameLength)  // Omnidirectional
        var x = [Float](repeating: 0, count: frameLength)  // Front-back
        var y = [Float](repeating: 0, count: frameLength)  // Left-right
        var z = [Float](repeating: 0, count: frameLength)  // Up-down

        let n = vDSP_Length(frameLength)

        for i in 0..<min(sourceCount, monoInputs.count) {
            let input = monoInputs[i]
            let azimuth = azimuths[i]
            let elevation = elevations[i]
            let amplitude = amplitudes[i]

            // Ambisonics encoding coefficients
            let cosAz = cos(azimuth)
            let sinAz = sin(azimuth)
            let cosEl = cos(elevation)
            let sinEl = sin(elevation)

            var wCoeff = amplitude * 0.707  // W = 1/√2
            var xCoeff = amplitude * cosAz * cosEl
            var yCoeff = amplitude * sinAz * cosEl
            var zCoeff = amplitude * sinEl

            // Accumulate contributions
            vDSP_vsma(input, 1, &wCoeff, w, 1, &w, 1, n)
            vDSP_vsma(input, 1, &xCoeff, x, 1, &x, 1, n)
            vDSP_vsma(input, 1, &yCoeff, y, 1, &y, 1, n)
            vDSP_vsma(input, 1, &zCoeff, z, 1, &z, 1, n)
        }

        return AmbisonicsFrame(w: w, x: x, y: y, z: z)
    }

    // MARK: - Source Management

    func setSourcePosition(index: Int, position: simd_float3) {
        guard index < config.maxSources else { return }
        positionsX[index] = position.x
        positionsY[index] = position.y
        positionsZ[index] = position.z
    }

    func setSourceVelocity(index: Int, velocity: simd_float3) {
        guard index < config.maxSources else { return }
        velocitiesX[index] = velocity.x
        velocitiesY[index] = velocity.y
        velocitiesZ[index] = velocity.z
    }

    func setSourceOrbital(index: Int, radius: Float, speed: Float, phase: Float, axis: simd_float3 = simd_float3(0, 1, 0)) {
        guard index < config.maxSources else { return }
        orbitalRadii[index] = radius
        orbitalSpeeds[index] = speed
        orbitalPhases[index] = phase
        orbitalAxes[index] = axis
    }

    func setTargetPosition(index: Int, position: simd_float3) {
        guard index < config.maxSources else { return }
        targetPositionsX[index] = position.x
        targetPositionsY[index] = position.y
        targetPositionsZ[index] = position.z
    }

    func setListenerPosition(_ position: simd_float3) {
        listenerPosition = position
    }

    func setListenerOrientation(_ orientation: simd_quatf) {
        listenerOrientation = orientation
    }

    func setListenerVelocity(_ velocity: simd_float3) {
        listenerVelocity = velocity
    }

    // MARK: - Batch Processing

    /// Process all spatial audio for a frame
    func processFrame(
        sourceCount: Int,
        deltaTime: Float,
        monoInputs: [[Float]],
        mode: SpatialMode
    ) -> SpatialAudioOutput {
        // Update orbital motion
        update4DOrbitalMotion(sourceCount: sourceCount, deltaTime: deltaTime)

        // Interpolate positions for smooth motion
        interpolatePositions(sourceCount: sourceCount, factor: 0.1)

        // Calculate spatial parameters
        calculateDistances(sourceCount: sourceCount)
        calculateAttenuation(sourceCount: sourceCount)

        switch mode {
        case .stereo:
            let (left, right) = calculateStereoPanning(sourceCount: sourceCount)
            return SpatialAudioOutput(
                stereoLeft: mixWithGains(monoInputs, gains: left),
                stereoRight: mixWithGains(monoInputs, gains: right)
            )

        case .binaural:
            var leftMix = [Float](repeating: 0, count: monoInputs.first?.count ?? 0)
            var rightMix = [Float](repeating: 0, count: monoInputs.first?.count ?? 0)

            for i in 0..<min(sourceCount, monoInputs.count) {
                let (left, right) = processHRTF(monoInput: monoInputs[i], sourceIndex: i)
                vDSP_vadd(leftMix, 1, left, 1, &leftMix, 1, vDSP_Length(left.count))
                vDSP_vadd(rightMix, 1, right, 1, &rightMix, 1, vDSP_Length(right.count))
            }

            return SpatialAudioOutput(stereoLeft: leftMix, stereoRight: rightMix)

        case .ambisonics:
            let ambi = encodeAmbisonics(sourceCount: sourceCount, monoInputs: monoInputs)
            return SpatialAudioOutput(ambisonics: ambi)
        }
    }

    private func mixWithGains(_ inputs: [[Float]], gains: [Float]) -> [Float] {
        guard let first = inputs.first else { return [] }
        var output = [Float](repeating: 0, count: first.count)
        let n = vDSP_Length(first.count)

        for (i, input) in inputs.enumerated() where i < gains.count {
            var gain = gains[i]
            vDSP_vsma(input, 1, &gain, output, 1, &output, 1, n)
        }

        return output
    }

    // MARK: - Types

    enum SpatialMode {
        case stereo
        case binaural
        case ambisonics
    }

    struct AmbisonicsFrame {
        let w: [Float]  // Omnidirectional
        let x: [Float]  // Front-back
        let y: [Float]  // Left-right
        let z: [Float]  // Up-down
    }

    struct SpatialAudioOutput {
        var stereoLeft: [Float] = []
        var stereoRight: [Float] = []
        var ambisonics: AmbisonicsFrame?
    }
}
