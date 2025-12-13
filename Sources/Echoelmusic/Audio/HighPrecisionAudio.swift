import Foundation
import Accelerate

/// High-Precision Audio Mathematics
///
/// All calculations with maximum precision (12+ decimal places).
/// Uses Double (64-bit) throughout for scientific accuracy.
///
/// Precision levels:
/// - Frequency: 0.000001 Hz (microhertz)
/// - Time: 0.000001 ms (nanoseconds)
/// - Cents: 0.0001 cents (microcents)
/// - Phase: 0.000001 degrees
/// - Amplitude: 0.0000001 (7 decimal places)
@MainActor
class HighPrecisionAudio: ObservableObject {

    // MARK: - Precision Constants

    /// Pi with maximum Double precision
    static let pi: Double = 3.141592653589793238

    /// 2 * Pi
    static let twoPi: Double = 6.283185307179586477

    /// Natural logarithm of 2
    static let ln2: Double = 0.693147180559945309

    /// Log base 2 of 10
    static let log2of10: Double = 3.321928094887362348

    // MARK: - Concert Pitch (12 decimal precision)

    /// A4 frequencies with maximum precision
    enum PreciseConcertPitch: Double, CaseIterable {
        case a415 = 415.000000000000
        case a430 = 430.000000000000
        case a432 = 432.000000000000
        case a435 = 435.000000000000
        case a440 = 440.000000000000
        case a441 = 441.000000000000
        case a442 = 442.000000000000
        case a443 = 443.000000000000
        case a444 = 444.000000000000
        case a446 = 446.000000000000

        var frequency: Double { rawValue }

        /// Cents from A440 with microcent precision
        var centsFromA440: Double {
            1200.0 * log2(rawValue / 440.0)
        }

        /// Ratio to A440
        var ratioToA440: Double {
            rawValue / 440.0
        }
    }

    /// Active concert pitch
    @Published var concertPitch: Double = 440.000000000000

    // MARK: - Tempo (Microsecond Precision)

    /// Tempo in BPM with 6 decimal places
    @Published var tempo: Double = 120.000000 {
        didSet {
            recalculateAllTimings()
        }
    }

    /// Quarter note duration in milliseconds
    var quarterNoteMs: Double {
        60000.000000000000 / tempo
    }

    /// Quarter note duration in seconds
    var quarterNoteSec: Double {
        60.000000000000 / tempo
    }

    /// Quarter note duration in samples
    func quarterNoteSamples(sampleRate: Double) -> Double {
        sampleRate * 60.0 / tempo
    }

    /// Beats per second
    var beatsPerSecond: Double {
        tempo / 60.000000000000
    }

    /// Beat period in seconds
    var beatPeriodSec: Double {
        60.000000000000 / tempo
    }

    /// Beat frequency in Hz
    var beatFrequencyHz: Double {
        tempo / 60.000000000000
    }

    // MARK: - Note Duration Calculator

    /// Note duration with maximum precision
    struct NoteDuration {
        let whole: Double           // 1/1
        let half: Double            // 1/2
        let quarter: Double         // 1/4
        let eighth: Double          // 1/8
        let sixteenth: Double       // 1/16
        let thirtySecond: Double    // 1/32
        let sixtyFourth: Double     // 1/64
        let oneHundredTwentyEighth: Double  // 1/128

        // Dotted versions
        let dottedWhole: Double
        let dottedHalf: Double
        let dottedQuarter: Double
        let dottedEighth: Double
        let dottedSixteenth: Double

        // Triplet versions
        let tripletWhole: Double
        let tripletHalf: Double
        let tripletQuarter: Double
        let tripletEighth: Double
        let tripletSixteenth: Double

        // Quintuplet versions
        let quintupletQuarter: Double
        let quintupletEighth: Double

        // Septuplet versions
        let septupletQuarter: Double
        let septupletEighth: Double
    }

    /// Current note durations in milliseconds
    @Published private(set) var durationsMs: NoteDuration = NoteDuration(
        whole: 2000.0, half: 1000.0, quarter: 500.0, eighth: 250.0,
        sixteenth: 125.0, thirtySecond: 62.5, sixtyFourth: 31.25,
        oneHundredTwentyEighth: 15.625,
        dottedWhole: 3000.0, dottedHalf: 1500.0, dottedQuarter: 750.0,
        dottedEighth: 375.0, dottedSixteenth: 187.5,
        tripletWhole: 1333.333333, tripletHalf: 666.666667,
        tripletQuarter: 333.333333, tripletEighth: 166.666667,
        tripletSixteenth: 83.333333,
        quintupletQuarter: 400.0, quintupletEighth: 200.0,
        septupletQuarter: 285.714286, septupletEighth: 142.857143
    )

    private func recalculateAllTimings() {
        let q = quarterNoteMs

        durationsMs = NoteDuration(
            whole: q * 4.000000000000,
            half: q * 2.000000000000,
            quarter: q,
            eighth: q / 2.000000000000,
            sixteenth: q / 4.000000000000,
            thirtySecond: q / 8.000000000000,
            sixtyFourth: q / 16.000000000000,
            oneHundredTwentyEighth: q / 32.000000000000,
            dottedWhole: q * 6.000000000000,
            dottedHalf: q * 3.000000000000,
            dottedQuarter: q * 1.500000000000,
            dottedEighth: q * 0.750000000000,
            dottedSixteenth: q * 0.375000000000,
            tripletWhole: q * 8.000000000000 / 3.000000000000,
            tripletHalf: q * 4.000000000000 / 3.000000000000,
            tripletQuarter: q * 2.000000000000 / 3.000000000000,
            tripletEighth: q * 1.000000000000 / 3.000000000000,
            tripletSixteenth: q * 0.500000000000 / 3.000000000000,
            quintupletQuarter: q * 4.000000000000 / 5.000000000000,
            quintupletEighth: q * 2.000000000000 / 5.000000000000,
            septupletQuarter: q * 4.000000000000 / 7.000000000000,
            septupletEighth: q * 2.000000000000 / 7.000000000000
        )
    }

    // MARK: - Frequency Calculations (Microhertz Precision)

    /// MIDI to frequency with 12 decimal precision
    /// Formula: f = A4 × 2^((n-69)/12)
    func midiToFrequency(_ midiNote: Double) -> Double {
        return concertPitch * pow(2.0, (midiNote - 69.000000000000) / 12.000000000000)
    }

    /// Frequency to MIDI with 12 decimal precision
    func frequencyToMidi(_ frequency: Double) -> Double {
        return 69.000000000000 + 12.000000000000 * log2(frequency / concertPitch)
    }

    /// Cents between frequencies with microcent precision
    func centsBetween(_ f1: Double, _ f2: Double) -> Double {
        return 1200.000000000000 * log2(f2 / f1)
    }

    /// Frequency with cents offset (microcent precision)
    func frequencyWithCents(_ baseFreq: Double, cents: Double) -> Double {
        return baseFreq * pow(2.0, cents / 1200.000000000000)
    }

    /// Frequency ratio from cents
    func centsToRatio(_ cents: Double) -> Double {
        return pow(2.0, cents / 1200.000000000000)
    }

    /// Cents from ratio
    func ratioToCents(_ ratio: Double) -> Double {
        return 1200.000000000000 * log2(ratio)
    }

    // MARK: - Wavelength Calculations

    /// Speed of sound with temperature compensation
    /// c = 331.3 + 0.606 × T (m/s)
    func speedOfSound(celsius: Double) -> Double {
        return 331.300000000000 + 0.606000000000 * celsius
    }

    /// Wavelength in meters with millimeter precision
    func wavelength(frequency: Double, celsius: Double = 20.0) -> Double {
        return speedOfSound(celsius: celsius) / frequency
    }

    /// Wavelength in centimeters
    func wavelengthCm(frequency: Double, celsius: Double = 20.0) -> Double {
        return wavelength(frequency: frequency, celsius: celsius) * 100.0
    }

    // MARK: - Phase Calculations (Microdegree Precision)

    /// Phase shift in degrees for delay at frequency
    func phaseShiftDegrees(delayMs: Double, frequencyHz: Double) -> Double {
        let periodMs = 1000.000000000000 / frequencyHz
        return (delayMs / periodMs) * 360.000000000000
    }

    /// Delay for specific phase shift
    func delayForPhase(degrees: Double, frequencyHz: Double) -> Double {
        let periodMs = 1000.000000000000 / frequencyHz
        return (degrees / 360.000000000000) * periodMs
    }

    /// Phase in radians
    func phaseRadians(delayMs: Double, frequencyHz: Double) -> Double {
        let periodMs = 1000.000000000000 / frequencyHz
        return (delayMs / periodMs) * Self.twoPi
    }

    // MARK: - Just Intonation Ratios (Exact Fractions)

    /// Just intonation intervals as exact ratios
    enum JustInterval {
        case unison         // 1/1
        case minorSecond    // 16/15
        case majorSecond    // 9/8
        case minorThird     // 6/5
        case majorThird     // 5/4
        case perfectFourth  // 4/3
        case tritone        // 45/32
        case perfectFifth   // 3/2
        case minorSixth     // 8/5
        case majorSixth     // 5/3
        case minorSeventh   // 9/5
        case majorSeventh   // 15/8
        case octave         // 2/1

        /// Exact rational ratio
        var ratio: (numerator: Int, denominator: Int) {
            switch self {
            case .unison: return (1, 1)
            case .minorSecond: return (16, 15)
            case .majorSecond: return (9, 8)
            case .minorThird: return (6, 5)
            case .majorThird: return (5, 4)
            case .perfectFourth: return (4, 3)
            case .tritone: return (45, 32)
            case .perfectFifth: return (3, 2)
            case .minorSixth: return (8, 5)
            case .majorSixth: return (5, 3)
            case .minorSeventh: return (9, 5)
            case .majorSeventh: return (15, 8)
            case .octave: return (2, 1)
            }
        }

        /// Decimal ratio with maximum precision
        var decimalRatio: Double {
            let r = ratio
            return Double(r.numerator) / Double(r.denominator)
        }

        /// Cents value (calculated, not rounded)
        var cents: Double {
            return 1200.0 * log2(decimalRatio)
        }

        /// Deviation from equal temperament in cents
        var deviationFromET: Double {
            let etCents: Double
            switch self {
            case .unison: etCents = 0
            case .minorSecond: etCents = 100
            case .majorSecond: etCents = 200
            case .minorThird: etCents = 300
            case .majorThird: etCents = 400
            case .perfectFourth: etCents = 500
            case .tritone: etCents = 600
            case .perfectFifth: etCents = 700
            case .minorSixth: etCents = 800
            case .majorSixth: etCents = 900
            case .minorSeventh: etCents = 1000
            case .majorSeventh: etCents = 1100
            case .octave: etCents = 1200
            }
            return cents - etCents
        }
    }

    /// Calculate just interval frequency
    func justIntervalFrequency(_ base: Double, interval: JustInterval) -> Double {
        return base * interval.decimalRatio
    }

    // MARK: - Harmonic Series

    /// Generate harmonic series frequencies with precision
    func harmonicSeries(_ fundamental: Double, count: Int) -> [Double] {
        return (1...count).map { Double($0) * fundamental }
    }

    /// Subharmonic series
    func subharmonicSeries(_ fundamental: Double, count: Int) -> [Double] {
        return (1...count).map { fundamental / Double($0) }
    }

    // MARK: - Decibel Calculations (High Precision)

    /// Amplitude to dB
    func amplitudeToDb(_ amplitude: Double) -> Double {
        guard amplitude > 0 else { return -Double.infinity }
        return 20.000000000000 * log10(amplitude)
    }

    /// dB to amplitude
    func dbToAmplitude(_ dB: Double) -> Double {
        return pow(10.0, dB / 20.000000000000)
    }

    /// Power to dB
    func powerToDb(_ power: Double) -> Double {
        guard power > 0 else { return -Double.infinity }
        return 10.000000000000 * log10(power)
    }

    /// dB to power
    func dbToPower(_ dB: Double) -> Double {
        return pow(10.0, dB / 10.000000000000)
    }

    // MARK: - Sample Rate Conversions

    /// Samples to milliseconds
    func samplesToMs(_ samples: Double, sampleRate: Double) -> Double {
        return samples / sampleRate * 1000.000000000000
    }

    /// Milliseconds to samples
    func msToSamples(_ ms: Double, sampleRate: Double) -> Double {
        return ms * sampleRate / 1000.000000000000
    }

    /// Samples to seconds
    func samplesToSeconds(_ samples: Double, sampleRate: Double) -> Double {
        return samples / sampleRate
    }

    /// Frequency to period samples
    func frequencyToPeriodSamples(_ frequency: Double, sampleRate: Double) -> Double {
        return sampleRate / frequency
    }

    // MARK: - Display Formatting

    /// Format frequency with specified decimal places
    func formatFrequency(_ freq: Double, decimals: Int = 6) -> String {
        return String(format: "%.\(decimals)f Hz", freq)
    }

    /// Format milliseconds with specified decimal places
    func formatMs(_ ms: Double, decimals: Int = 6) -> String {
        return String(format: "%.\(decimals)f ms", ms)
    }

    /// Format cents with specified decimal places
    func formatCents(_ cents: Double, decimals: Int = 4) -> String {
        let sign = cents >= 0 ? "+" : ""
        return String(format: "\(sign)%.\(decimals)f ¢", cents)
    }

    /// Format BPM with specified decimal places
    func formatBpm(_ bpm: Double, decimals: Int = 6) -> String {
        return String(format: "%.\(decimals)f BPM", bpm)
    }

    // MARK: - Initialization

    init() {
        recalculateAllTimings()
    }
}

// MARK: - Precision Display View Model

extension HighPrecisionAudio {

    /// Get all current values formatted for display
    func getAllFormattedValues() -> [String: String] {
        return [
            "Concert Pitch": formatFrequency(concertPitch, decimals: 12),
            "Tempo": formatBpm(tempo, decimals: 6),
            "Quarter Note": formatMs(quarterNoteMs, decimals: 9),
            "Eighth Note": formatMs(durationsMs.eighth, decimals: 9),
            "Sixteenth Note": formatMs(durationsMs.sixteenth, decimals: 9),
            "Triplet Quarter": formatMs(durationsMs.tripletQuarter, decimals: 9),
            "Beat Frequency": formatFrequency(beatFrequencyHz, decimals: 9),
            "A4": formatFrequency(midiToFrequency(69), decimals: 9),
            "C4 (Middle C)": formatFrequency(midiToFrequency(60), decimals: 9),
            "E4": formatFrequency(midiToFrequency(64), decimals: 9),
            "Perfect Fifth (JI)": formatCents(JustInterval.perfectFifth.cents, decimals: 6),
            "Major Third (JI)": formatCents(JustInterval.majorThird.cents, decimals: 6),
        ]
    }
}
