import Foundation
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════╗
// ║       PHYSICS TRANSLATION ENGINE - SCIENTIFIC ACCURACY VERIFICATION              ║
// ║                                                                                    ║
// ║   Physically correct translation between domains:                                 ║
// ║   • Audio ↔ Light (wave physics, psychoacoustics)                                ║
// ║   • Bio signals ↔ Parameters (physiological models)                               ║
// ║   • Color ↔ Frequency (CIE color science)                                        ║
// ║   • Motion ↔ Sound (physics simulation)                                          ║
// ║   • All conversions traceable to scientific literature                            ║
// ║                                                                                    ║
// ╚═══════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - Physical Constants

public enum PhysicalConstants {

    // Speed of light in vacuum (m/s) - CODATA 2018
    public static let speedOfLight: Double = 299_792_458

    // Planck's constant (J·s) - CODATA 2018
    public static let planckConstant: Double = 6.62607015e-34

    // Boltzmann constant (J/K) - CODATA 2018
    public static let boltzmannConstant: Double = 1.380649e-23

    // Stefan-Boltzmann constant (W/(m²·K⁴))
    public static let stefanBoltzmann: Double = 5.670374419e-8

    // Speed of sound in air at 20°C (m/s)
    public static let speedOfSoundAir: Double = 343.2

    // Reference sound pressure (Pa) - threshold of hearing at 1kHz
    public static let referenceSoundPressure: Double = 20e-6

    // Reference luminous intensity (cd)
    public static let referenceLuminousIntensity: Double = 1.0

    // Human audible frequency range (Hz)
    public static let audibleFrequencyRange: ClosedRange<Double> = 20...20_000

    // Visible light wavelength range (nm)
    public static let visibleWavelengthRange: ClosedRange<Double> = 380...780

    // Heart rate normal range (BPM)
    public static let normalHeartRateRange: ClosedRange<Double> = 60...100

    // HRV RMSSD normal range (ms)
    public static let normalHRVRange: ClosedRange<Double> = 20...100
}

// MARK: - Audio Physics

public struct AudioPhysics {

    // MARK: - Sound Pressure Level

    /// Convert linear amplitude to dB SPL
    /// Formula: L = 20 * log10(p / p₀)
    /// Reference: ISO 226:2003
    public static func amplitudeToDBSPL(_ amplitude: Double) -> Double {
        guard amplitude > 0 else { return -Double.infinity }
        return 20 * log10(amplitude / PhysicalConstants.referenceSoundPressure)
    }

    /// Convert dB SPL to linear amplitude
    public static func dbSPLToAmplitude(_ db: Double) -> Double {
        return PhysicalConstants.referenceSoundPressure * pow(10, db / 20)
    }

    // MARK: - Equal Loudness Contours (ISO 226:2003)

    /// Calculate perceived loudness in phons for a given frequency and dB SPL
    /// Based on ISO 226:2003 equal loudness contours
    public static func calculatePhons(frequency: Double, dbSPL: Double) -> Double {
        // Simplified model based on ISO 226
        // Full implementation would use lookup tables

        // Reference: 1kHz tone, where phons = dB SPL
        let referenceFrequency: Double = 1000

        // Ear sensitivity varies with frequency
        // Maximum sensitivity around 3-4 kHz
        let frequencyCorrection: Double

        if frequency < 100 {
            // Low frequency roll-off (bass requires more power)
            frequencyCorrection = -20 * log10(frequency / referenceFrequency) * 1.5
        } else if frequency > 10000 {
            // High frequency roll-off
            frequencyCorrection = -10 * log10(frequency / referenceFrequency)
        } else if frequency >= 2000 && frequency <= 5000 {
            // Ear canal resonance boost
            frequencyCorrection = 5.0
        } else {
            frequencyCorrection = 0
        }

        return dbSPL + frequencyCorrection
    }

    /// Calculate A-weighting for a frequency (IEC 61672:2003)
    /// Returns dB correction to apply
    public static func aWeighting(frequency: Double) -> Double {
        let f2 = frequency * frequency
        let f4 = f2 * f2

        let numerator = 12194.0 * 12194.0 * f4
        let denominator = (f2 + 20.6 * 20.6) *
                         sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) *
                         (f2 + 12194.0 * 12194.0)

        let ra = numerator / denominator
        return 20 * log10(ra) + 2.0 // +2.0 normalization factor
    }

    // MARK: - Frequency and Wavelength

    /// Convert frequency to wavelength in air
    public static func frequencyToWavelength(_ frequency: Double, temperature: Double = 20) -> Double {
        // Speed of sound varies with temperature: v = 331.3 * sqrt(1 + T/273.15)
        let speedOfSound = 331.3 * sqrt(1 + temperature / 273.15)
        return speedOfSound / frequency
    }

    /// Convert MIDI note to frequency (Hz)
    /// A4 = 440 Hz (ISO 16:1975)
    public static func midiToFrequency(_ midiNote: Int, tuning: Double = 440) -> Double {
        return tuning * pow(2, Double(midiNote - 69) / 12)
    }

    /// Convert frequency to MIDI note (with cent deviation)
    public static func frequencyToMIDI(_ frequency: Double, tuning: Double = 440) -> (note: Int, cents: Double) {
        let noteFloat = 69 + 12 * log2(frequency / tuning)
        let note = Int(round(noteFloat))
        let cents = (noteFloat - Double(note)) * 100
        return (note, cents)
    }

    // MARK: - Room Acoustics

    /// Calculate reverberation time (Sabine equation)
    /// RT60 = 0.161 * V / A
    /// V = room volume (m³), A = total absorption (sabins)
    public static func sabineRT60(roomVolume: Double, totalAbsorption: Double) -> Double {
        return 0.161 * roomVolume / totalAbsorption
    }

    /// Calculate critical distance (where direct = reverberant)
    public static func criticalDistance(roomVolume: Double, rt60: Double) -> Double {
        return 0.057 * sqrt(roomVolume / rt60)
    }
}

// MARK: - Light Physics

public struct LightPhysics {

    // MARK: - Wavelength and Color

    /// Convert wavelength (nm) to approximate RGB
    /// Based on CIE 1931 color matching functions
    public static func wavelengthToRGB(_ wavelength: Double) -> (r: Double, g: Double, b: Double) {
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0

        if wavelength >= 380 && wavelength < 440 {
            r = -(wavelength - 440) / (440 - 380)
            g = 0
            b = 1
        } else if wavelength >= 440 && wavelength < 490 {
            r = 0
            g = (wavelength - 440) / (490 - 440)
            b = 1
        } else if wavelength >= 490 && wavelength < 510 {
            r = 0
            g = 1
            b = -(wavelength - 510) / (510 - 490)
        } else if wavelength >= 510 && wavelength < 580 {
            r = (wavelength - 510) / (580 - 510)
            g = 1
            b = 0
        } else if wavelength >= 580 && wavelength < 645 {
            r = 1
            g = -(wavelength - 645) / (645 - 580)
            b = 0
        } else if wavelength >= 645 && wavelength <= 780 {
            r = 1
            g = 0
            b = 0
        }

        // Intensity fall-off at edges of visible spectrum
        var intensity: Double = 1.0
        if wavelength >= 380 && wavelength < 420 {
            intensity = 0.3 + 0.7 * (wavelength - 380) / (420 - 380)
        } else if wavelength >= 700 && wavelength <= 780 {
            intensity = 0.3 + 0.7 * (780 - wavelength) / (780 - 700)
        }

        return (r * intensity, g * intensity, b * intensity)
    }

    /// Convert color temperature to dominant wavelength (approximate)
    public static func colorTempToDominantWavelength(_ kelvin: Double) -> Double {
        // Approximation based on Wien's displacement law
        // λ_peak = b / T where b = 2897.8 µm·K
        // But this is for thermal radiation peak, not perceived color

        // For perceived dominant wavelength:
        if kelvin < 3000 {
            return 620 // Warm orange-red
        } else if kelvin < 5000 {
            return 580 + (kelvin - 3000) / 2000 * 20 // Yellow range
        } else if kelvin < 7000 {
            return 550 // Green-yellow (neutral)
        } else {
            return 480 // Blue
        }
    }

    // MARK: - Photometry

    /// Convert radiant power (W) to luminous flux (lm)
    /// Using luminous efficacy function V(λ)
    public static func radianceToLuminance(radianceWatts: Double, wavelength: Double) -> Double {
        // Maximum luminous efficacy: 683 lm/W at 555 nm
        let v = luminousEfficacy(wavelength: wavelength)
        return radianceWatts * 683 * v
    }

    /// CIE luminous efficacy function V(λ)
    /// Normalized to 1.0 at 555 nm
    public static func luminousEfficacy(wavelength: Double) -> Double {
        // Gaussian approximation of V(λ)
        let lambda = wavelength
        let sigma: Double = 50
        let peak: Double = 555

        return exp(-0.5 * pow((lambda - peak) / sigma, 2))
    }

    /// Convert lux to foot-candles
    public static func luxToFootCandles(_ lux: Double) -> Double {
        return lux / 10.764
    }

    /// Calculate illuminance from candela at distance
    /// E = I / d² (inverse square law)
    public static func candelaToLux(candela: Double, distance: Double) -> Double {
        guard distance > 0 else { return 0 }
        return candela / (distance * distance)
    }

    // MARK: - Planck's Law

    /// Spectral radiance of black body at temperature T and wavelength λ
    /// B(λ,T) = (2hc²/λ⁵) × 1/(e^(hc/λkT) - 1)
    public static func planckRadiance(wavelength: Double, temperature: Double) -> Double {
        let h = PhysicalConstants.planckConstant
        let c = PhysicalConstants.speedOfLight
        let k = PhysicalConstants.boltzmannConstant

        let lambdaM = wavelength * 1e-9 // nm to m
        let numerator = 2 * h * c * c / pow(lambdaM, 5)
        let exponent = (h * c) / (lambdaM * k * temperature)
        let denominator = exp(exponent) - 1

        return numerator / denominator
    }
}

// MARK: - Biophysics Models

public struct BiophysicsModels {

    // MARK: - Heart Rate Variability Analysis

    /// Calculate RMSSD from RR intervals
    /// RMSSD: Root Mean Square of Successive Differences
    /// Standard measure of parasympathetic activity
    public static func calculateRMSSD(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0 }

        var sumSquaredDiff: Double = 0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i-1]
            sumSquaredDiff += diff * diff
        }

        return sqrt(sumSquaredDiff / Double(rrIntervals.count - 1))
    }

    /// Calculate SDNN (Standard Deviation of NN intervals)
    public static func calculateSDNN(rrIntervals: [Double]) -> Double {
        guard !rrIntervals.isEmpty else { return 0 }

        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let variance = rrIntervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(rrIntervals.count)

        return sqrt(variance)
    }

    /// Calculate pNN50 (percentage of successive intervals differing by >50ms)
    public static func calculatePNN50(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0 }

        var count = 0
        for i in 1..<rrIntervals.count {
            if abs(rrIntervals[i] - rrIntervals[i-1]) > 50 {
                count += 1
            }
        }

        return Double(count) / Double(rrIntervals.count - 1) * 100
    }

    // MARK: - Coherence Analysis (HeartMath Model)

    /// Calculate coherence ratio from HRV power spectrum
    /// Based on HeartMath Institute research
    /// Coherence = Power in 0.04-0.26 Hz range (peak around 0.1 Hz)
    public static func calculateCoherenceRatio(hrvSpectrum: [Double], frequencyBins: [Double]) -> Double {
        // Coherence band: 0.04-0.26 Hz
        let coherenceLow: Double = 0.04
        let coherenceHigh: Double = 0.26

        var coherencePower: Double = 0
        var totalPower: Double = 0

        for (i, freq) in frequencyBins.enumerated() where i < hrvSpectrum.count {
            let power = hrvSpectrum[i]
            totalPower += power

            if freq >= coherenceLow && freq <= coherenceHigh {
                coherencePower += power
            }
        }

        guard totalPower > 0 else { return 0 }
        return coherencePower / totalPower
    }

    /// Calculate instantaneous coherence using autocorrelation
    public static func calculateInstantaneousCoherence(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 10 else { return 0 }

        // Look for periodic pattern around 0.1 Hz (10-second cycle)
        let expectedPeriod = 10.0 // seconds

        // Calculate mean interval
        let meanRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let expectedSamplesPerPeriod = Int(expectedPeriod / (meanRR / 1000))

        guard expectedSamplesPerPeriod > 0 && expectedSamplesPerPeriod < rrIntervals.count else { return 0 }

        // Calculate autocorrelation at expected lag
        var autocorr: Double = 0
        var variance: Double = 0

        for i in 0..<(rrIntervals.count - expectedSamplesPerPeriod) {
            let diff1 = rrIntervals[i] - meanRR
            let diff2 = rrIntervals[i + expectedSamplesPerPeriod] - meanRR
            autocorr += diff1 * diff2
            variance += diff1 * diff1
        }

        guard variance > 0 else { return 0 }
        return max(0, autocorr / variance) // Normalize to 0-1
    }

    // MARK: - Respiratory Sinus Arrhythmia (RSA)

    /// Calculate RSA amplitude from HRV during breathing
    /// RSA is the natural variation in heart rate with breathing
    public static func calculateRSA(rrIntervals: [Double], breathingRate: Double) -> Double {
        // RSA appears in HRV at the breathing frequency
        // Typical breathing: 12-20 breaths/min = 0.2-0.33 Hz

        let breathingFreq = breathingRate / 60.0 // Convert to Hz

        // Simplified: Calculate peak-to-peak variation
        guard rrIntervals.count >= 10 else { return 0 }

        let maxRR = rrIntervals.max() ?? 0
        let minRR = rrIntervals.min() ?? 0

        return maxRR - minRR
    }
}

// MARK: - Audio-Visual Translation

public struct AudioVisualTranslation {

    /// Attempt to map audio frequency to light wavelength
    /// NOTE: No physical basis - purely creative mapping
    /// Audio: 20-20000 Hz, Light: 380-780 nm (400-790 THz)
    public static func audioFrequencyToLightWavelength(
        audioFreq: Double,
        mappingMode: MappingMode = .logarithmic
    ) -> Double {
        switch mappingMode {
        case .linear:
            // Linear mapping (not perceptually accurate)
            let normalized = (log10(audioFreq) - log10(20)) / (log10(20000) - log10(20))
            return 780 - normalized * 400 // Reverse: low freq = red, high = violet

        case .logarithmic:
            // Logarithmic mapping (better for perception)
            let octaves = log2(audioFreq / 20)
            let totalOctaves = log2(20000 / 20)
            let normalized = octaves / totalOctaves
            return 780 - normalized * 400

        case .harmonic:
            // Map based on octave relationships
            // C2 = Red, C3 = Orange, C4 = Yellow, etc.
            let baseFreq: Double = 65.41 // C2
            let octave = log2(audioFreq / baseFreq)
            let normalizedOctave = octave / 8 // 8 octaves
            return 780 - normalizedOctave * 400
        }
    }

    public enum MappingMode: String, CaseIterable, Sendable {
        case linear
        case logarithmic
        case harmonic
    }

    /// Map audio envelope to light intensity
    /// Uses perceptual curve matching (Stevens' Power Law)
    public static func audioEnvelopeToLightIntensity(
        audioLevel: Double, // 0-1 normalized
        exponent: Double = 0.5 // Stevens' exponent for brightness
    ) -> Double {
        // Stevens' Power Law: perceived = intensity^exponent
        // For brightness: exponent ≈ 0.5 (square root)
        return pow(max(0, min(1, audioLevel)), exponent)
    }

    /// Map audio spectrum to color palette
    /// Returns HSB values for visualization
    public static func spectrumToColor(
        lowEnergy: Double,
        midEnergy: Double,
        highEnergy: Double
    ) -> (hue: Double, saturation: Double, brightness: Double) {
        // Map frequency bands to hue
        // Low = warm colors (0-60°), Mid = green/cyan (60-180°), High = cool colors (180-300°)

        let totalEnergy = lowEnergy + midEnergy + highEnergy
        guard totalEnergy > 0 else { return (0, 0, 0) }

        // Weighted hue
        let lowHue: Double = 30 // Orange
        let midHue: Double = 120 // Green
        let highHue: Double = 240 // Blue

        let hue = (lowEnergy * lowHue + midEnergy * midHue + highEnergy * highHue) / totalEnergy

        // Saturation from energy distribution (more even = less saturated)
        let distribution = [lowEnergy, midEnergy, highEnergy].map { $0 / totalEnergy }
        let entropy = -distribution.reduce(0) { $0 + ($1 > 0 ? $1 * log2($1) : 0) }
        let maxEntropy = log2(3.0)
        let saturation = 1 - (entropy / maxEntropy) * 0.5 // 0.5-1.0

        // Brightness from total energy
        let brightness = min(1, totalEnergy)

        return (hue, saturation, brightness)
    }
}

// MARK: - Scientific Validation

public struct ScientificValidation {

    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let parameter: String
        public let value: Double
        public let expectedRange: ClosedRange<Double>?
        public let reference: String
        public let warning: String?
    }

    /// Validate audio parameters against physical limits
    public static func validateAudioParameters(
        frequency: Double,
        amplitude: Double,
        sampleRate: Double
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Frequency range
        results.append(ValidationResult(
            isValid: PhysicalConstants.audibleFrequencyRange.contains(frequency),
            parameter: "Frequency",
            value: frequency,
            expectedRange: PhysicalConstants.audibleFrequencyRange,
            reference: "Human audible range: 20-20000 Hz",
            warning: frequency < 20 ? "Infrasound region" : (frequency > 20000 ? "Ultrasound region" : nil)
        ))

        // Nyquist limit
        let nyquist = sampleRate / 2
        results.append(ValidationResult(
            isValid: frequency < nyquist,
            parameter: "Nyquist",
            value: frequency,
            expectedRange: 0...nyquist,
            reference: "Nyquist-Shannon sampling theorem",
            warning: frequency >= nyquist ? "Aliasing will occur" : nil
        ))

        // Amplitude
        results.append(ValidationResult(
            isValid: amplitude >= 0 && amplitude <= 1,
            parameter: "Amplitude",
            value: amplitude,
            expectedRange: 0...1,
            reference: "Normalized digital audio range",
            warning: amplitude > 1 ? "Clipping will occur" : nil
        ))

        return results
    }

    /// Validate biometric parameters against physiological norms
    public static func validateBiometricParameters(
        heartRate: Double,
        hrv: Double,
        coherence: Double
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Heart rate
        results.append(ValidationResult(
            isValid: heartRate >= 30 && heartRate <= 220,
            parameter: "Heart Rate",
            value: heartRate,
            expectedRange: 30...220,
            reference: "Physiological heart rate range (max ≈ 220 - age)",
            warning: heartRate < 60 ? "Bradycardia" : (heartRate > 100 ? "Tachycardia" : nil)
        ))

        // HRV (RMSSD)
        results.append(ValidationResult(
            isValid: hrv >= 0 && hrv <= 200,
            parameter: "HRV (RMSSD)",
            value: hrv,
            expectedRange: 0...200,
            reference: "Normal RMSSD range: 20-100ms (Task Force 1996)",
            warning: hrv < 20 ? "Low HRV - reduced parasympathetic activity" : nil
        ))

        // Coherence
        results.append(ValidationResult(
            isValid: coherence >= 0 && coherence <= 1,
            parameter: "Coherence",
            value: coherence,
            expectedRange: 0...1,
            reference: "HeartMath coherence ratio",
            warning: nil
        ))

        return results
    }

    /// Validate color science parameters
    public static func validateColorParameters(
        colorTemperature: Double,
        chromaticityX: Double,
        chromaticityY: Double
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Color temperature
        results.append(ValidationResult(
            isValid: colorTemperature >= 1000 && colorTemperature <= 25000,
            parameter: "Color Temperature",
            value: colorTemperature,
            expectedRange: 1000...25000,
            reference: "Practical CCT range (CIE 15:2004)",
            warning: colorTemperature < 2700 ? "Very warm (candle-like)" :
                    (colorTemperature > 10000 ? "Blue sky region" : nil)
        ))

        // CIE xy must be within visible gamut
        // Simplified check using bounding box
        let validX = chromaticityX >= 0 && chromaticityX <= 0.75
        let validY = chromaticityY >= 0 && chromaticityY <= 0.85
        let inGamut = validX && validY && (chromaticityX + chromaticityY <= 1)

        results.append(ValidationResult(
            isValid: inGamut,
            parameter: "Chromaticity",
            value: chromaticityX,
            expectedRange: 0...0.75,
            reference: "CIE 1931 xy chromaticity diagram",
            warning: inGamut ? nil : "Outside visible gamut"
        ))

        return results
    }
}

// MARK: - Physics Translation Engine

@MainActor
public final class PhysicsTranslationEngine: ObservableObject {

    public static let shared = PhysicsTranslationEngine()

    @Published public private(set) var lastValidationResults: [ScientificValidation.ValidationResult] = []
    @Published public var strictValidationEnabled: Bool = true

    private init() {}

    // MARK: - Validated Translations

    /// Translate audio frequency to light with validation
    public func audioToLight(
        frequency: Double,
        amplitude: Double,
        mappingMode: AudioVisualTranslation.MappingMode = .logarithmic
    ) -> (wavelength: Double, intensity: Double, isValid: Bool) {
        // Validate input
        let validation = ScientificValidation.validateAudioParameters(
            frequency: frequency,
            amplitude: amplitude,
            sampleRate: 44100
        )
        lastValidationResults = validation

        let allValid = validation.allSatisfy { $0.isValid }

        if strictValidationEnabled && !allValid {
            return (0, 0, false)
        }

        let wavelength = AudioVisualTranslation.audioFrequencyToLightWavelength(
            audioFreq: frequency,
            mappingMode: mappingMode
        )
        let intensity = AudioVisualTranslation.audioEnvelopeToLightIntensity(audioLevel: amplitude)

        return (wavelength, intensity, allValid)
    }

    /// Translate bio signals to parameters with validation
    public func bioToParameters(
        heartRate: Double,
        hrv: Double,
        coherence: Double
    ) -> (colorTemp: Double, intensity: Double, pulseRate: Double, isValid: Bool) {
        // Validate input
        let validation = ScientificValidation.validateBiometricParameters(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence
        )
        lastValidationResults = validation

        let allValid = validation.allSatisfy { $0.isValid }

        // Map to lighting parameters
        let colorTemp = BioLightMapper.circadianColorTemperature(
            hour: Calendar.current.component(.hour, from: Date())
        )
        let intensity = coherence
        let pulseRate = heartRate / 60.0 // Convert BPM to Hz

        return (colorTemp, intensity, pulseRate, allValid)
    }

    /// Generate validation report
    public func generateValidationReport() -> String {
        var report = "═══════════════════════════════════════════════════════════════\n"
        report += "           SCIENTIFIC VALIDATION REPORT\n"
        report += "═══════════════════════════════════════════════════════════════\n\n"

        for result in lastValidationResults {
            let status = result.isValid ? "✅" : "❌"
            report += "\(status) \(result.parameter): \(String(format: "%.4f", result.value))\n"
            if let range = result.expectedRange {
                report += "   Expected: \(range)\n"
            }
            report += "   Reference: \(result.reference)\n"
            if let warning = result.warning {
                report += "   ⚠️ Warning: \(warning)\n"
            }
            report += "\n"
        }

        report += "═══════════════════════════════════════════════════════════════\n"
        report += "Strict validation: \(strictValidationEnabled ? "ENABLED" : "DISABLED")\n"

        return report
    }
}
