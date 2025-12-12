import Foundation
import Accelerate

// MARK: - Frequency Science Module
// Pure physics-based frequency calculations with high precision
// NO esoteric claims - only peer-reviewed science

/// FrequencyScience - High-Precision Frequency Calculations
///
/// All calculations use Double precision (64-bit IEEE 754):
/// - 15-17 significant decimal digits
/// - Range: ±1.7×10^308
/// - Precision: ~2.22×10^-16 relative error
///
/// **Physical Constants (CODATA 2018):**
/// - Speed of light: 299,792,458 m/s (exact)
/// - Planck constant: 6.62607015×10^-34 J·s (exact)
/// - Boltzmann constant: 1.380649×10^-23 J/K (exact)
///
/// **No Claims Made:**
/// - No "healing frequencies"
/// - No "chakra frequencies"
/// - No "DNA repair frequencies"
/// - Pure physics only
public enum FrequencyScience {

    // MARK: - Physical Constants (CODATA 2018 - Exact Definitions)

    /// Speed of light in vacuum (m/s) - exact by SI definition
    public static let speedOfLight: Double = 299_792_458.0

    /// Planck constant (J·s) - exact by SI definition since 2019
    public static let planckConstant: Double = 6.62607015e-34

    /// Boltzmann constant (J/K) - exact by SI definition since 2019
    public static let boltzmannConstant: Double = 1.380649e-23

    /// Wien's displacement constant (m·K)
    public static let wienConstant: Double = 2.897771955e-3

    /// Stefan-Boltzmann constant (W·m^-2·K^-4)
    public static let stefanBoltzmann: Double = 5.670374419e-8

    // MARK: - Electromagnetic Spectrum Boundaries

    /// Visible light frequency range (Hz)
    public static let visibleLightMin: Double = 400e12  // 400 THz (red)
    public static let visibleLightMax: Double = 789e12  // 789 THz (violet)

    /// Visible light wavelength range (nm)
    public static let visibleWavelengthMin: Double = 380.0  // violet
    public static let visibleWavelengthMax: Double = 750.0  // red

    /// Human hearing frequency range (Hz)
    public static let hearingMin: Double = 20.0
    public static let hearingMax: Double = 20_000.0

    // MARK: - Frequency-Wavelength Conversion

    /// Convert frequency to wavelength
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Wavelength in meters
    /// - Formula: λ = c / f
    public static func frequencyToWavelength(_ frequency: Double) -> Double {
        guard frequency > 0 else { return 0 }
        return speedOfLight / frequency
    }

    /// Convert frequency to wavelength in nanometers
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Wavelength in nanometers (nm)
    public static func frequencyToWavelengthNm(_ frequency: Double) -> Double {
        return frequencyToWavelength(frequency) * 1e9
    }

    /// Convert wavelength to frequency
    /// - Parameter wavelength: Wavelength in meters
    /// - Returns: Frequency in Hz
    /// - Formula: f = c / λ
    public static func wavelengthToFrequency(_ wavelength: Double) -> Double {
        guard wavelength > 0 else { return 0 }
        return speedOfLight / wavelength
    }

    /// Convert wavelength in nanometers to frequency
    /// - Parameter wavelengthNm: Wavelength in nanometers
    /// - Returns: Frequency in Hz
    public static func wavelengthNmToFrequency(_ wavelengthNm: Double) -> Double {
        return wavelengthToFrequency(wavelengthNm * 1e-9)
    }

    // MARK: - Musical Frequency Calculations

    /// Standard concert pitch A4 (Hz) - ISO 16:1975
    public static let concertPitchA4: Double = 440.0

    /// MIDI note number for A4
    public static let midiNoteA4: Int = 69

    /// Convert MIDI note to frequency using equal temperament
    /// - Parameters:
    ///   - midiNote: MIDI note number (0-127)
    ///   - referenceA4: Reference frequency for A4 (default: 440 Hz)
    /// - Returns: Frequency in Hz with full Double precision
    /// - Formula: f = A4 × 2^((n-69)/12)
    public static func midiToFrequency(
        _ midiNote: Int,
        referenceA4: Double = concertPitchA4
    ) -> Double {
        let semitoneRatio = Double(midiNote - midiNoteA4) / 12.0
        return referenceA4 * pow(2.0, semitoneRatio)
    }

    /// Convert frequency to MIDI note number
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - referenceA4: Reference frequency for A4 (default: 440 Hz)
    /// - Returns: MIDI note number as Double (includes cents deviation)
    /// - Formula: n = 69 + 12 × log2(f/A4)
    public static func frequencyToMidi(
        _ frequency: Double,
        referenceA4: Double = concertPitchA4
    ) -> Double {
        guard frequency > 0 else { return 0 }
        return 69.0 + 12.0 * log2(frequency / referenceA4)
    }

    /// Convert frequency to MIDI note with cents deviation
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - referenceA4: Reference frequency for A4 (default: 440 Hz)
    /// - Returns: Tuple of (midiNote: Int, cents: Double)
    public static func frequencyToMidiWithCents(
        _ frequency: Double,
        referenceA4: Double = concertPitchA4
    ) -> (midiNote: Int, cents: Double) {
        let exactMidi = frequencyToMidi(frequency, referenceA4: referenceA4)
        let nearestMidi = Int(round(exactMidi))
        let cents = (exactMidi - Double(nearestMidi)) * 100.0
        return (nearestMidi, cents)
    }

    /// Calculate interval ratio between two frequencies
    /// - Parameters:
    ///   - f1: First frequency
    ///   - f2: Second frequency
    /// - Returns: Ratio and cents difference
    public static func frequencyRatio(_ f1: Double, _ f2: Double) -> (ratio: Double, cents: Double) {
        guard f1 > 0 && f2 > 0 else { return (1.0, 0.0) }
        let ratio = f2 / f1
        let cents = 1200.0 * log2(ratio)
        return (ratio, cents)
    }

    // MARK: - Octave Transposition (Physics-Based)

    /// Transpose frequency by octaves
    /// - Parameters:
    ///   - frequency: Original frequency in Hz
    ///   - octaves: Number of octaves (positive = up, negative = down)
    /// - Returns: Transposed frequency in Hz
    /// - Formula: f' = f × 2^n
    public static func transposeOctaves(_ frequency: Double, octaves: Double) -> Double {
        return frequency * pow(2.0, octaves)
    }

    /// Calculate octaves between two frequencies
    /// - Parameters:
    ///   - f1: First frequency
    ///   - f2: Second frequency
    /// - Returns: Number of octaves (can be fractional)
    /// - Formula: octaves = log2(f2/f1)
    public static func octavesBetween(_ f1: Double, _ f2: Double) -> Double {
        guard f1 > 0 && f2 > 0 else { return 0 }
        return log2(f2 / f1)
    }

    /// Transpose bio-frequency to audible range
    /// - Parameter bioFrequency: Frequency in Hz (typically 0.01-10 Hz)
    /// - Returns: Audible frequency in Hz (20-20000 Hz range)
    ///
    /// Uses minimum octave transposition to reach audible range while
    /// preserving harmonic relationships.
    public static func bioToAudible(_ bioFrequency: Double) -> Double {
        guard bioFrequency > 0 else { return hearingMin }

        if bioFrequency >= hearingMin {
            return bioFrequency  // Already audible
        }

        // Calculate minimum octaves needed
        let octavesNeeded = ceil(log2(hearingMin / bioFrequency))
        return bioFrequency * pow(2.0, octavesNeeded)
    }

    /// Map audible frequency to visible light frequency
    /// - Parameter audioFrequency: Frequency in Hz (20-20000 Hz)
    /// - Returns: Light frequency in Hz (~400-789 THz)
    ///
    /// Uses logarithmic mapping to compress ~10 audio octaves
    /// into ~1 visible light octave.
    public static func audioToLight(_ audioFrequency: Double) -> Double {
        // Clamp to hearing range
        let clampedAudio = max(hearingMin, min(hearingMax, audioFrequency))

        // Logarithmic position in audio spectrum (0-1)
        let audioOctaves = log2(hearingMax / hearingMin)  // ~9.97 octaves
        let audioPosition = log2(clampedAudio / hearingMin) / audioOctaves

        // Map to visible light range (logarithmic)
        let lightOctaves = log2(visibleLightMax / visibleLightMin)  // ~0.98 octaves
        let lightFrequency = visibleLightMin * pow(2.0, audioPosition * lightOctaves)

        return lightFrequency
    }

    // MARK: - Wavelength to RGB (CIE 1931 Approximation)

    /// Convert wavelength to RGB color
    /// - Parameter wavelengthNm: Wavelength in nanometers (380-750)
    /// - Returns: RGB tuple with values 0.0-1.0
    ///
    /// Based on CIE 1931 color matching functions approximation.
    /// Uses Dan Bruton's algorithm with gamma correction.
    public static func wavelengthToRGB(_ wavelengthNm: Double) -> (r: Double, g: Double, b: Double) {
        var r: Double = 0, g: Double = 0, b: Double = 0
        var factor: Double = 0

        switch wavelengthNm {
        case 380..<440:
            r = -(wavelengthNm - 440.0) / (440.0 - 380.0)
            g = 0.0
            b = 1.0
        case 440..<490:
            r = 0.0
            g = (wavelengthNm - 440.0) / (490.0 - 440.0)
            b = 1.0
        case 490..<510:
            r = 0.0
            g = 1.0
            b = -(wavelengthNm - 510.0) / (510.0 - 490.0)
        case 510..<580:
            r = (wavelengthNm - 510.0) / (580.0 - 510.0)
            g = 1.0
            b = 0.0
        case 580..<645:
            r = 1.0
            g = -(wavelengthNm - 645.0) / (645.0 - 580.0)
            b = 0.0
        case 645...780:
            r = 1.0
            g = 0.0
            b = 0.0
        default:
            r = 0.0
            g = 0.0
            b = 0.0
        }

        // Intensity correction at spectrum edges
        switch wavelengthNm {
        case 380..<420:
            factor = 0.3 + 0.7 * (wavelengthNm - 380.0) / (420.0 - 380.0)
        case 420..<701:
            factor = 1.0
        case 701...780:
            factor = 0.3 + 0.7 * (780.0 - wavelengthNm) / (780.0 - 700.0)
        default:
            factor = 0.0
        }

        // Gamma correction (γ = 0.8)
        let gamma = 0.8
        r = pow(r * factor, gamma)
        g = pow(g * factor, gamma)
        b = pow(b * factor, gamma)

        return (r, g, b)
    }

    /// Convert audio frequency directly to RGB color
    /// - Parameter audioFrequency: Frequency in Hz
    /// - Returns: RGB tuple with values 0.0-1.0
    public static func audioFrequencyToRGB(_ audioFrequency: Double) -> (r: Double, g: Double, b: Double) {
        let lightFrequency = audioToLight(audioFrequency)
        let wavelength = frequencyToWavelengthNm(lightFrequency)
        return wavelengthToRGB(wavelength)
    }

    // MARK: - Brainwave Frequency Bands (Neuroscience-Based)

    /// Brainwave frequency bands based on clinical EEG standards
    /// Reference: Niedermeyer & da Silva, "Electroencephalography" (2005)
    public enum BrainwaveBand: CaseIterable {
        case delta      // 0.5-4 Hz
        case theta      // 4-8 Hz
        case alpha      // 8-12 Hz
        case smr        // 12-15 Hz (Sensorimotor Rhythm)
        case beta       // 15-30 Hz
        case gamma      // 30-100 Hz

        public var frequencyRange: ClosedRange<Double> {
            switch self {
            case .delta: return 0.5...4.0
            case .theta: return 4.0...8.0
            case .alpha: return 8.0...12.0
            case .smr:   return 12.0...15.0
            case .beta:  return 15.0...30.0
            case .gamma: return 30.0...100.0
            }
        }

        public var centerFrequency: Double {
            let range = frequencyRange
            return (range.lowerBound + range.upperBound) / 2.0
        }

        /// Clinical associations (peer-reviewed)
        public var clinicalAssociation: String {
            switch self {
            case .delta: return "Deep sleep, slow-wave sleep (stages 3-4)"
            case .theta: return "Drowsiness, light sleep, memory consolidation"
            case .alpha: return "Relaxed wakefulness, eyes closed"
            case .smr:   return "Relaxed focus, motor inhibition"
            case .beta:  return "Active thinking, concentration, alertness"
            case .gamma: return "Higher cognitive function, perception binding"
            }
        }

        /// Determine brainwave band from frequency
        public static func band(for frequency: Double) -> BrainwaveBand? {
            for band in allCases {
                if band.frequencyRange.contains(frequency) {
                    return band
                }
            }
            return nil
        }
    }

    // MARK: - Binaural Beat Frequency Calculation

    /// Calculate binaural beat parameters
    /// - Parameters:
    ///   - targetBeatFrequency: Desired beat frequency (Hz)
    ///   - carrierFrequency: Base carrier frequency (Hz)
    /// - Returns: Left and right ear frequencies
    ///
    /// Reference: Oster, G. (1973). "Auditory beats in the brain"
    public static func binauralBeatFrequencies(
        targetBeatFrequency: Double,
        carrierFrequency: Double
    ) -> (leftEar: Double, rightEar: Double) {
        let halfBeat = targetBeatFrequency / 2.0
        return (
            leftEar: carrierFrequency - halfBeat,
            rightEar: carrierFrequency + halfBeat
        )
    }

    // MARK: - Resonance Frequency Calculation

    /// Calculate resonance frequency for a simple harmonic oscillator
    /// - Parameters:
    ///   - mass: Mass in kg
    ///   - stiffness: Spring constant in N/m
    /// - Returns: Natural frequency in Hz
    /// - Formula: f = (1/2π) × √(k/m)
    public static func resonanceFrequency(mass: Double, stiffness: Double) -> Double {
        guard mass > 0 && stiffness > 0 else { return 0 }
        return (1.0 / (2.0 * .pi)) * sqrt(stiffness / mass)
    }

    /// Calculate string resonance frequency
    /// - Parameters:
    ///   - length: String length in meters
    ///   - tension: String tension in Newtons
    ///   - linearDensity: Mass per unit length in kg/m
    ///   - harmonic: Harmonic number (1 = fundamental)
    /// - Returns: Frequency in Hz
    /// - Formula: f_n = (n/2L) × √(T/μ)
    public static func stringResonanceFrequency(
        length: Double,
        tension: Double,
        linearDensity: Double,
        harmonic: Int = 1
    ) -> Double {
        guard length > 0 && tension > 0 && linearDensity > 0 && harmonic > 0 else { return 0 }
        return (Double(harmonic) / (2.0 * length)) * sqrt(tension / linearDensity)
    }

    // MARK: - Precision Formatting

    /// Format frequency with appropriate precision
    /// - Parameters:
    ///   - frequency: Frequency in Hz
    ///   - decimalPlaces: Number of decimal places (0-10)
    /// - Returns: Formatted string with unit
    public static func formatFrequency(_ frequency: Double, decimalPlaces: Int = 2) -> String {
        let places = max(0, min(10, decimalPlaces))

        if frequency >= 1e12 {
            return String(format: "%.\(places)f THz", frequency / 1e12)
        } else if frequency >= 1e9 {
            return String(format: "%.\(places)f GHz", frequency / 1e9)
        } else if frequency >= 1e6 {
            return String(format: "%.\(places)f MHz", frequency / 1e6)
        } else if frequency >= 1e3 {
            return String(format: "%.\(places)f kHz", frequency / 1e3)
        } else if frequency >= 1 {
            return String(format: "%.\(places)f Hz", frequency)
        } else if frequency >= 1e-3 {
            return String(format: "%.\(places)f mHz", frequency * 1e3)
        } else {
            return String(format: "%.\(places)e Hz", frequency)
        }
    }

    /// Format frequency with full precision (up to 15 decimal places)
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Full precision string
    public static func formatFrequencyFullPrecision(_ frequency: Double) -> String {
        return String(format: "%.15g Hz", frequency)
    }
}

// MARK: - High-Precision FFT Analysis

/// FFT-based frequency analysis with Double precision
public struct PrecisionFFTAnalyzer {

    /// Perform FFT and return frequency spectrum
    /// - Parameters:
    ///   - samples: Input samples (Double precision)
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Array of (frequency, magnitude) tuples
    public static func analyze(
        samples: [Double],
        sampleRate: Double
    ) -> [(frequency: Double, magnitude: Double)] {
        let n = samples.count
        guard n > 0 && (n & (n - 1)) == 0 else {
            // Require power of 2
            return []
        }

        // Prepare FFT
        let log2n = vDSP_Length(log2(Double(n)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        // Apply Hann window
        var window = [Double](repeating: 0, count: n)
        vDSP_hann_windowD(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        var windowedSamples = [Double](repeating: 0, count: n)
        vDSP_vmulD(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(n))

        // Split complex format
        var realp = [Double](repeating: 0, count: n/2)
        var imagp = [Double](repeating: 0, count: n/2)

        // Convert to split complex
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: n/2) { complexPtr in
                var splitComplex = DSPDoubleSplitComplex(realp: &realp, imagp: &imagp)
                vDSP_ctozD(complexPtr, 2, &splitComplex, 1, vDSP_Length(n/2))
            }
        }

        // Perform FFT
        var splitComplex = DSPDoubleSplitComplex(realp: &realp, imagp: &imagp)
        vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitudes
        var magnitudes = [Double](repeating: 0, count: n/2)
        vDSP_zvmagsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(n/2))

        // Scale and convert to dB
        var scaledMagnitudes = [Double](repeating: 0, count: n/2)
        var scale = 1.0 / Double(n)
        vDSP_vsmulD(magnitudes, 1, &scale, &scaledMagnitudes, 1, vDSP_Length(n/2))

        // Create frequency-magnitude pairs
        let frequencyResolution = sampleRate / Double(n)
        var result: [(frequency: Double, magnitude: Double)] = []

        for i in 0..<(n/2) {
            let frequency = Double(i) * frequencyResolution
            let magnitude = sqrt(scaledMagnitudes[i])
            result.append((frequency, magnitude))
        }

        return result
    }

    /// Find dominant frequency in spectrum
    /// - Parameters:
    ///   - samples: Input samples
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Dominant frequency with parabolic interpolation for sub-bin accuracy
    public static func dominantFrequency(
        samples: [Double],
        sampleRate: Double
    ) -> Double {
        let spectrum = analyze(samples: samples, sampleRate: sampleRate)
        guard spectrum.count > 2 else { return 0 }

        // Find peak
        var peakIndex = 0
        var peakMagnitude: Double = 0
        for (index, bin) in spectrum.enumerated() {
            if bin.magnitude > peakMagnitude {
                peakMagnitude = bin.magnitude
                peakIndex = index
            }
        }

        // Parabolic interpolation for sub-bin accuracy
        guard peakIndex > 0 && peakIndex < spectrum.count - 1 else {
            return spectrum[peakIndex].frequency
        }

        let alpha = spectrum[peakIndex - 1].magnitude
        let beta = spectrum[peakIndex].magnitude
        let gamma = spectrum[peakIndex + 1].magnitude

        let p = 0.5 * (alpha - gamma) / (alpha - 2.0 * beta + gamma)

        let frequencyResolution = sampleRate / Double(samples.count)
        return (Double(peakIndex) + p) * frequencyResolution
    }
}
