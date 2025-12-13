import Foundation
import Accelerate

/// Psychoacoustic Analyzer
///
/// Implements scientifically validated models of human auditory perception.
/// Based on ISO standards and peer-reviewed psychoacoustic research.
///
/// References:
/// - ISO 226:2003 - Equal loudness contours
/// - ISO 532-1:2017 - Loudness calculation (Zwicker method)
/// - Moore, B.C.J. (2012) "An Introduction to the Psychology of Hearing"
/// - Zwicker, E. & Fastl, H. (2007) "Psychoacoustics: Facts and Models"
@MainActor
class PsychoacousticAnalyzer: ObservableObject {

    // MARK: - Constants

    /// Standard reference for sound pressure level
    private let referencePresure: Float = 20e-6  // 20 µPa (threshold of hearing)

    /// Sample rate for analysis
    private let sampleRate: Float = 48000

    // MARK: - Equal Loudness Contours (ISO 226:2003)

    /// Calculate the threshold of hearing at a given frequency
    /// Based on ISO 226:2003 - the lowest SPL audible at each frequency
    /// Returns SPL in dB
    func thresholdOfHearing(atFrequency f: Float) -> Float {
        // Terhardt's approximation of threshold curve
        // L_th(f) = 3.64(f/1000)^-0.8 - 6.5*exp(-0.6(f/1000-3.3)²) + 10^-3(f/1000)^4
        let fkHz = f / 1000.0

        let term1 = 3.64 * pow(fkHz, -0.8)
        let term2 = -6.5 * exp(-0.6 * pow(fkHz - 3.3, 2))
        let term3 = 0.001 * pow(fkHz, 4)

        return term1 + term2 + term3
    }

    /// Equal loudness contour for a given phon level
    /// Returns the SPL required at each frequency to produce that loudness
    func equalLoudnessContour(phonLevel: Float, frequencies: [Float]) -> [Float] {
        var spls: [Float] = []

        for f in frequencies {
            let spl = splForPhon(phon: phonLevel, frequency: f)
            spls.append(spl)
        }

        return spls
    }

    /// Convert phon to SPL at a given frequency (ISO 226:2003 approximation)
    private func splForPhon(phon: Float, frequency: Float) -> Float {
        // At 1kHz, phon = dB SPL by definition
        // At other frequencies, use transfer function

        let threshold = thresholdOfHearing(atFrequency: frequency)
        let threshold1k = thresholdOfHearing(atFrequency: 1000)

        // Loudness level transfer
        let alpha = 0.4 + 0.0003 * (phon - 40)  // Slope varies with level

        // ISO 226 approximation
        let deltaThreshold = threshold - threshold1k
        let spl = phon + deltaThreshold * alpha

        return spl
    }

    // MARK: - Loudness Calculation (Zwicker Method)

    /// Critical band rate (Bark scale) - Zwicker & Terhardt
    /// Maps frequency to perceptual scale where each Bark ≈ one critical bandwidth
    func frequencyToBark(_ f: Float) -> Float {
        // z = 13 * arctan(0.00076f) + 3.5 * arctan((f/7500)²)
        return 13.0 * atan(0.00076 * f) + 3.5 * atan(pow(f / 7500.0, 2))
    }

    /// Inverse Bark to frequency
    func barkToFrequency(_ z: Float) -> Float {
        // Numerical approximation (inverse of Bark formula)
        // f ≈ 600 * sinh(z/6)
        return 600.0 * sinh(z / 6.0)
    }

    /// Critical bandwidth at a given frequency
    /// CB(f) = 25 + 75 * (1 + 1.4(f/1000)²)^0.69
    func criticalBandwidth(atFrequency f: Float) -> Float {
        let fkHz = f / 1000.0
        return 25.0 + 75.0 * pow(1.0 + 1.4 * fkHz * fkHz, 0.69)
    }

    /// Calculate specific loudness in sones per Bark
    /// Based on Zwicker's model
    func specificLoudness(excitation: Float, bark: Float) -> Float {
        // Threshold in quiet (bark-dependent)
        let thresholdExcitation = pow(10, thresholdOfHearing(atFrequency: barkToFrequency(bark)) / 10.0)

        if excitation <= thresholdExcitation {
            return 0
        }

        // Stevens' power law with corrections
        let exponent: Float = 0.23
        let referenceExcitation: Float = 1e-12  // Reference for sone calculation

        return pow(excitation / referenceExcitation, exponent)
    }

    /// Total loudness in sones (ISO 532 simplified)
    func totalLoudness(spectrum: [Float], frequencies: [Float]) -> Float {
        guard spectrum.count == frequencies.count else { return 0 }

        // Convert to specific loudness per critical band
        var totalSones: Float = 0
        var previousBark: Float = 0

        for i in 0..<spectrum.count {
            let bark = frequencyToBark(frequencies[i])
            let barkWidth = bark - previousBark

            if barkWidth > 0 {
                let excitation = pow(10, spectrum[i] / 10.0)
                let specificLoud = specificLoudness(excitation: excitation, bark: bark)
                totalSones += specificLoud * barkWidth
            }

            previousBark = bark
        }

        return totalSones
    }

    /// Convert sones to phons
    func sonesToPhons(_ sones: Float) -> Float {
        // N = 2^((P-40)/10) for P >= 40 phons
        // P = 40 + 10 * log2(N)
        if sones <= 0 { return 0 }
        return 40.0 + 10.0 * log2(sones)
    }

    /// Convert phons to sones
    func phonsToSones(_ phons: Float) -> Float {
        // N = 2^((P-40)/10)
        return pow(2.0, (phons - 40.0) / 10.0)
    }

    // MARK: - Temporal Masking

    /// Forward (post-) masking - masker sound reduces audibility of following sounds
    /// Duration: typically 100-200ms
    /// Reference: Moore (2012), Chapter 4
    struct TemporalMaskingResult {
        let maskerEndTime: Float      // When masker ends (seconds)
        let recoveryTime: Float       // Time to full recovery (seconds)
        let maskingCurve: [(time: Float, threshold: Float)]  // Threshold over time
    }

    /// Calculate forward masking threshold curve
    /// The masker raises the threshold for sounds following it
    func forwardMasking(
        maskerLevel: Float,       // dB SPL
        maskerDuration: Float,    // seconds
        maskerFrequency: Float    // Hz
    ) -> TemporalMaskingResult {
        // Forward masking decays approximately linearly in dB over 100-200ms

        let maxMasking = maskerLevel - 10  // Max threshold elevation
        let recoveryTime: Float = 0.2       // 200ms typical recovery

        var curve: [(Float, Float)] = []
        let steps = 50

        for i in 0..<steps {
            let t = Float(i) / Float(steps - 1) * recoveryTime
            // Linear decay in dB
            let thresholdElevation = maxMasking * (1.0 - t / recoveryTime)
            let threshold = thresholdOfHearing(atFrequency: maskerFrequency) + max(0, thresholdElevation)
            curve.append((maskerDuration + t, threshold))
        }

        return TemporalMaskingResult(
            maskerEndTime: maskerDuration,
            recoveryTime: recoveryTime,
            maskingCurve: curve
        )
    }

    /// Backward (pre-) masking - masker sound reduces audibility of preceding sounds
    /// Duration: typically 10-20ms
    /// Less effective than forward masking
    func backwardMasking(
        maskerLevel: Float,
        maskerFrequency: Float
    ) -> TemporalMaskingResult {
        let maxMasking = maskerLevel - 20  // Less effective than forward
        let preMaskingDuration: Float = 0.02  // 20ms

        var curve: [(Float, Float)] = []
        let steps = 20

        for i in 0..<steps {
            let t = Float(steps - 1 - i) / Float(steps - 1) * preMaskingDuration
            let thresholdElevation = maxMasking * (1.0 - t / preMaskingDuration)
            let threshold = thresholdOfHearing(atFrequency: maskerFrequency) + max(0, thresholdElevation)
            curve.append((-t, threshold))
        }

        return TemporalMaskingResult(
            maskerEndTime: 0,
            recoveryTime: preMaskingDuration,
            maskingCurve: curve.reversed()
        )
    }

    // MARK: - Simultaneous Masking

    /// Spreading function for simultaneous masking
    /// How a masker at one frequency affects detection at other frequencies
    func spreadingFunction(maskerBark: Float, signalBark: Float, maskerLevel: Float) -> Float {
        let deltaBark = signalBark - maskerBark

        // Spreading is asymmetric - more upward spread than downward
        let slope: Float
        if deltaBark >= 0 {
            // Upward spread (signal frequency > masker)
            // Slope increases with level: steeper at high levels
            slope = -27.0 + 0.37 * max(maskerLevel - 40, 0)
        } else {
            // Downward spread (signal frequency < masker)
            slope = -24.0  // More gentle slope
        }

        // Spreading in dB
        return slope * abs(deltaBark)
    }

    /// Calculate masking threshold at all frequencies given a masker
    func simultaneousMaskingThreshold(
        maskerFrequency: Float,
        maskerLevel: Float,
        signalFrequencies: [Float]
    ) -> [Float] {
        let maskerBark = frequencyToBark(maskerFrequency)
        var thresholds: [Float] = []

        for f in signalFrequencies {
            let signalBark = frequencyToBark(f)
            let spreading = spreadingFunction(maskerBark: maskerBark, signalBark: signalBark, maskerLevel: maskerLevel)

            // Masked threshold
            let maskedThreshold = maskerLevel + spreading
            // Absolute threshold
            let absoluteThreshold = thresholdOfHearing(atFrequency: f)

            // Take the higher of masked and absolute threshold
            thresholds.append(max(maskedThreshold, absoluteThreshold))
        }

        return thresholds
    }

    // MARK: - Pitch Perception

    /// Just noticeable difference (JND) in frequency
    /// Based on frequency discrimination experiments
    /// Reference: Moore (2012), Chapter 6
    func frequencyJND(atFrequency f: Float) -> Float {
        // Below 500 Hz: ~3 Hz
        // Above 500 Hz: ~0.6% of frequency
        if f < 500 {
            return 3.0
        } else {
            return f * 0.006
        }
    }

    /// Weber fraction for frequency discrimination
    /// Δf/f is approximately constant above 500 Hz
    func frequencyWeberFraction(atFrequency f: Float) -> Float {
        return frequencyJND(atFrequency: f) / f
    }

    // MARK: - Duration Perception

    /// Minimum integration time for pitch perception
    /// Below this, pitch becomes unclear
    func minimumPitchDuration(atFrequency f: Float) -> Float {
        // Approximately 2-3 periods minimum
        return 3.0 / f
    }

    /// Loudness integration time
    /// Sounds shorter than this are perceived as softer
    static let loudnessIntegrationTime: Float = 0.2  // ~200ms

    /// Loudness correction for short sounds
    /// Sounds < 200ms are perceived as quieter
    func shortDurationLoudnessCorrection(durationMs: Float) -> Float {
        if durationMs >= 200 {
            return 0  // No correction needed
        }

        // Approximately 10 dB decrease per decade of duration below 200ms
        return 10.0 * log10(durationMs / 200.0)
    }
}

// MARK: - A-Weighting

extension PsychoacousticAnalyzer {

    /// A-weighting filter (IEC 61672)
    /// Approximates human frequency response at moderate levels
    func aWeighting(atFrequency f: Float) -> Float {
        let f2 = f * f
        let f4 = f2 * f2

        let numerator = 12194.0 * 12194.0 * f4
        let denominator = (f2 + 20.6 * 20.6) *
                         sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) *
                         (f2 + 12194.0 * 12194.0)

        let ra = numerator / denominator

        // Convert to dB and add reference offset
        return 20.0 * log10(ra) + 2.0  // +2 dB offset for normalization at 1kHz
    }

    /// Apply A-weighting to spectrum
    func applyAWeighting(spectrum: [Float], frequencies: [Float]) -> [Float] {
        guard spectrum.count == frequencies.count else { return spectrum }

        var weighted = [Float](repeating: 0, count: spectrum.count)
        for i in 0..<spectrum.count {
            weighted[i] = spectrum[i] + aWeighting(atFrequency: frequencies[i])
        }
        return weighted
    }
}

// MARK: - Consonance/Dissonance

extension PsychoacousticAnalyzer {

    /// Plomp-Levelt roughness model for two pure tones
    /// Dissonance is maximum when frequency difference ≈ 25% of critical bandwidth
    func roughness(frequency1: Float, frequency2: Float) -> Float {
        let fLow = min(frequency1, frequency2)
        let fHigh = max(frequency1, frequency2)
        let deltaF = fHigh - fLow

        // Critical bandwidth at the lower frequency
        let cb = criticalBandwidth(atFrequency: fLow)

        // Normalized frequency difference
        let x = deltaF / cb

        // Plomp-Levelt curve: max roughness at x ≈ 0.25
        // R(x) = x * exp(1 - x) for x = Δf / (0.25 * CB)
        let xNorm = x / 0.25
        let roughness = xNorm * exp(1.0 - xNorm)

        return max(0, min(1, roughness))
    }

    /// Sensory consonance for a set of partials
    /// Lower roughness = more consonant
    func sensoryConsonance(frequencies: [Float], amplitudes: [Float]) -> Float {
        guard frequencies.count == amplitudes.count, frequencies.count > 1 else {
            return 1.0  // Single tone is maximally consonant
        }

        var totalRoughness: Float = 0
        var totalWeight: Float = 0

        for i in 0..<frequencies.count {
            for j in (i + 1)..<frequencies.count {
                let r = roughness(frequency1: frequencies[i], frequency2: frequencies[j])
                let weight = amplitudes[i] * amplitudes[j]
                totalRoughness += r * weight
                totalWeight += weight
            }
        }

        if totalWeight > 0 {
            let avgRoughness = totalRoughness / totalWeight
            return 1.0 - avgRoughness  // Convert roughness to consonance
        }

        return 1.0
    }
}
