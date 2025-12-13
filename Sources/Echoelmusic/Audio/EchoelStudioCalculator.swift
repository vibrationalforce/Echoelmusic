import Foundation
import Accelerate

/// EchoelStudio Calculator - Professional Audio Mathematics
///
/// Comprehensive audio calculations with high precision (6+ decimal places).
/// Based on Sengpielaudio.com formulas and professional audio standards.
///
/// Use cases:
/// - Real-time streaming & worldwide collaboration
/// - Concert & studio production
/// - Schools & educational institutions
/// - Health & therapy facilities (Yoga, movement therapy)
/// - Theater & performance venues
/// - Health sciences & movement sciences research
///
/// References:
/// - sengpielaudio.com (Eberhard Sengpiel, Tonmeister)
/// - ISO 16:1975 (A4 = 440 Hz standard)
/// - ISO 266:1997 (Preferred frequencies for acoustics)
/// - Sabine, W.C. (1922) "Collected Papers on Acoustics"
@MainActor
class EchoelStudioCalculator: ObservableObject {

    // MARK: - Singleton
    static let shared = EchoelStudioCalculator()

    // MARK: - High-Precision Constants

    /// Speed of sound at 20°C (m/s) - 6 decimal precision
    static let speedOfSound20C: Double = 343.210000

    /// Speed of sound calculation coefficient
    static let speedOfSoundCoefficient: Double = 331.300000

    /// Speed of sound temperature coefficient (m/s per °C)
    static let speedOfSoundTempCoeff: Double = 0.606000

    // MARK: - Concert Pitch Standards (Kammertöne)

    /// All available concert pitch standards
    enum ConcertPitch: String, CaseIterable, Identifiable {
        case a415 = "A415 Baroque"
        case a430 = "A430 Classical"
        case a432 = "A432 Verdi"
        case a435 = "A435 French"
        case a440 = "A440 ISO Standard"
        case a441 = "A441 US Orchestras"
        case a442 = "A442 European"
        case a443 = "A443 Berlin Phil"
        case a444 = "A444 Chamber"
        case a446 = "A446 Bright"

        var id: String { rawValue }

        /// Frequency in Hz (high precision)
        var frequency: Double {
            switch self {
            case .a415: return 415.000000
            case .a430: return 430.000000
            case .a432: return 432.000000
            case .a435: return 435.000000
            case .a440: return 440.000000
            case .a441: return 441.000000
            case .a442: return 442.000000
            case .a443: return 443.000000
            case .a444: return 444.000000
            case .a446: return 446.000000
            }
        }

        /// Historical/practical context
        var description: String {
            switch self {
            case .a415: return "Baroque pitch - Bach, Handel era"
            case .a430: return "Classical pitch - Mozart, Beethoven era"
            case .a432: return "Verdi tuning - 'scientific pitch'"
            case .a435: return "French diapason normal (1859)"
            case .a440: return "ISO 16:1975 international standard"
            case .a441: return "Common in US orchestras"
            case .a442: return "Standard for European orchestras"
            case .a443: return "Berlin Philharmonic standard"
            case .a444: return "Bright chamber music tuning"
            case .a446: return "Extra bright orchestral tuning"
            }
        }

        /// Cents difference from A440
        var centsFromA440: Double {
            return 1200.0 * log2(frequency / 440.0)
        }
    }

    /// Custom concert pitch (any frequency)
    @Published var customConcertPitch: Double = 440.000000

    /// Currently selected concert pitch
    @Published var selectedConcertPitch: ConcertPitch = .a440

    /// Use custom pitch instead of preset
    @Published var useCustomPitch: Bool = false

    /// Active concert pitch frequency
    var activeConcertPitch: Double {
        useCustomPitch ? customConcertPitch : selectedConcertPitch.frequency
    }

    // MARK: - Tempo System (High Precision BPM)

    /// Current tempo with microsecond precision
    @Published var tempo: Double = 120.000000 {
        didSet {
            recalculateTimings()
        }
    }

    /// Tempo range limits
    static let tempoRange: ClosedRange<Double> = 20.000000...400.000000

    /// Calculated timing values (updated when tempo changes)
    @Published private(set) var timings: TempoTimings = TempoTimings()

    /// All calculated timing values for current tempo
    struct TempoTimings {
        var wholeNoteMs: Double = 2000.0
        var halfNoteMs: Double = 1000.0
        var quarterNoteMs: Double = 500.0
        var eighthNoteMs: Double = 250.0
        var sixteenthNoteMs: Double = 125.0
        var thirtySecondNoteMs: Double = 62.5
        var sixtyFourthNoteMs: Double = 31.25

        // Dotted notes
        var dottedWholeMs: Double = 3000.0
        var dottedHalfMs: Double = 1500.0
        var dottedQuarterMs: Double = 750.0
        var dottedEighthMs: Double = 375.0
        var dottedSixteenthMs: Double = 187.5

        // Triplets
        var tripletHalfMs: Double = 666.666667
        var tripletQuarterMs: Double = 333.333333
        var tripletEighthMs: Double = 166.666667
        var tripletSixteenthMs: Double = 83.333333

        // Frequency equivalents
        var beatsPerSecond: Double = 2.0
        var barsPerMinute: Double = 30.0  // 4/4 time
    }

    /// Recalculate all timings when tempo changes
    private func recalculateTimings() {
        let quarterMs = 60000.0 / tempo

        timings.quarterNoteMs = quarterMs
        timings.wholeNoteMs = quarterMs * 4.0
        timings.halfNoteMs = quarterMs * 2.0
        timings.eighthNoteMs = quarterMs / 2.0
        timings.sixteenthNoteMs = quarterMs / 4.0
        timings.thirtySecondNoteMs = quarterMs / 8.0
        timings.sixtyFourthNoteMs = quarterMs / 16.0

        // Dotted = note + half its value = 1.5x
        timings.dottedWholeMs = timings.wholeNoteMs * 1.5
        timings.dottedHalfMs = timings.halfNoteMs * 1.5
        timings.dottedQuarterMs = timings.quarterNoteMs * 1.5
        timings.dottedEighthMs = timings.eighthNoteMs * 1.5
        timings.dottedSixteenthMs = timings.sixteenthNoteMs * 1.5

        // Triplets = 2/3 of the note value
        timings.tripletHalfMs = timings.halfNoteMs * (2.0 / 3.0)
        timings.tripletQuarterMs = timings.quarterNoteMs * (2.0 / 3.0)
        timings.tripletEighthMs = timings.eighthNoteMs * (2.0 / 3.0)
        timings.tripletSixteenthMs = timings.sixteenthNoteMs * (2.0 / 3.0)

        timings.beatsPerSecond = tempo / 60.0
        timings.barsPerMinute = tempo / 4.0  // Assuming 4/4
    }

    // MARK: - Frequency Calculations

    /// MIDI note to frequency with high precision
    /// Formula: f = A4 × 2^((n-69)/12)
    func midiToFrequency(_ midiNote: Double) -> Double {
        return activeConcertPitch * pow(2.0, (midiNote - 69.0) / 12.0)
    }

    /// Frequency to MIDI note with high precision
    func frequencyToMidi(_ frequency: Double) -> Double {
        return 69.0 + 12.0 * log2(frequency / activeConcertPitch)
    }

    /// Frequency with cents offset
    func frequencyWithCents(_ baseFrequency: Double, cents: Double) -> Double {
        return baseFrequency * pow(2.0, cents / 1200.0)
    }

    /// Cents between two frequencies
    func centsBetween(_ freq1: Double, _ freq2: Double) -> Double {
        return 1200.0 * log2(freq2 / freq1)
    }

    /// Frequency ratio to cents
    func ratioToCents(_ ratio: Double) -> Double {
        return 1200.0 * log2(ratio)
    }

    /// Cents to frequency ratio
    func centsToRatio(_ cents: Double) -> Double {
        return pow(2.0, cents / 1200.0)
    }

    // MARK: - Note Name Conversion

    /// Note names (sharps)
    static let noteNamesSharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    /// Note names (flats)
    static let noteNamesFlats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    /// MIDI note to note name with octave
    func midiToNoteName(_ midiNote: Int, useFlats: Bool = false) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        let names = useFlats ? Self.noteNamesFlats : Self.noteNamesSharps
        return "\(names[noteIndex])\(octave)"
    }

    /// Frequency to note name with cents deviation
    func frequencyToNoteName(_ frequency: Double, useFlats: Bool = false) -> (name: String, cents: Double) {
        let midiFloat = frequencyToMidi(frequency)
        let midiRounded = Int(round(midiFloat))
        let centsDeviation = (midiFloat - Double(midiRounded)) * 100.0
        let name = midiToNoteName(midiRounded, useFlats: useFlats)
        return (name, centsDeviation)
    }

    // MARK: - Time Signature Support

    /// Calculate bar duration
    func barDuration(timeSignature: (Int, Int)) -> Double {
        let (numerator, denominator) = timeSignature
        let beatDuration = timings.quarterNoteMs * (4.0 / Double(denominator))
        return beatDuration * Double(numerator)
    }

    /// Bars per minute for given time signature
    func barsPerMinute(timeSignature: (Int, Int)) -> Double {
        let barMs = barDuration(timeSignature: timeSignature)
        return 60000.0 / barMs
    }

    // MARK: - Speed of Sound Calculations (Sengpiel)

    /// Speed of sound at given temperature
    /// Formula: c = 331.3 + 0.606 × T (m/s)
    func speedOfSound(temperatureCelsius: Double) -> Double {
        return Self.speedOfSoundCoefficient + Self.speedOfSoundTempCoeff * temperatureCelsius
    }

    /// Wavelength at given frequency and temperature
    func wavelength(frequency: Double, temperatureCelsius: Double = 20.0) -> Double {
        let c = speedOfSound(temperatureCelsius: temperatureCelsius)
        return c / frequency
    }

    /// Time for sound to travel distance
    func soundTravelTime(distanceMeters: Double, temperatureCelsius: Double = 20.0) -> Double {
        let c = speedOfSound(temperatureCelsius: temperatureCelsius)
        return distanceMeters / c * 1000.0  // Return in milliseconds
    }

    /// Distance sound travels in given time
    func soundTravelDistance(milliseconds: Double, temperatureCelsius: Double = 20.0) -> Double {
        let c = speedOfSound(temperatureCelsius: temperatureCelsius)
        return c * milliseconds / 1000.0
    }

    // MARK: - Room Acoustics (Sabine)

    /// RT60 reverberation time using Sabine formula
    /// RT60 = 0.161 × V / A
    func rt60Sabine(volumeM3: Double, absorptionArea: Double) -> Double {
        return 0.161 * volumeM3 / absorptionArea
    }

    /// Critical distance calculation
    /// Dc = 0.057 × √(V / RT60)
    func criticalDistance(volumeM3: Double, rt60: Double) -> Double {
        return 0.057 * sqrt(volumeM3 / rt60)
    }

    /// Room absorption area from dimensions and coefficient
    func absorptionArea(length: Double, width: Double, height: Double, coefficient: Double) -> Double {
        let surfaceArea = 2.0 * (length * width + length * height + width * height)
        return surfaceArea * coefficient
    }

    // MARK: - Decibel Calculations

    /// Voltage ratio to dB
    func voltageToDb(_ ratio: Double) -> Double {
        return 20.0 * log10(ratio)
    }

    /// Power ratio to dB
    func powerToDb(_ ratio: Double) -> Double {
        return 10.0 * log10(ratio)
    }

    /// dB to voltage ratio
    func dbToVoltage(_ dB: Double) -> Double {
        return pow(10.0, dB / 20.0)
    }

    /// dB to power ratio
    func dbToPower(_ dB: Double) -> Double {
        return pow(10.0, dB / 10.0)
    }

    /// Sum of dB levels (power addition)
    func sumDb(_ levels: [Double]) -> Double {
        let sumPower = levels.reduce(0.0) { $0 + pow(10.0, $1 / 10.0) }
        return 10.0 * log10(sumPower)
    }

    // MARK: - Delay/Phase Calculations

    /// Phase shift in degrees for delay at frequency
    func phaseShiftDegrees(delayMs: Double, frequencyHz: Double) -> Double {
        let period = 1000.0 / frequencyHz
        return (delayMs / period) * 360.0
    }

    /// Delay needed for specific phase shift
    func delayForPhaseShift(degrees: Double, frequencyHz: Double) -> Double {
        let period = 1000.0 / frequencyHz
        return (degrees / 360.0) * period
    }

    /// Comb filter frequencies for given delay
    func combFilterPeaks(delayMs: Double, maxFrequency: Double = 20000.0) -> [Double] {
        let delaySec = delayMs / 1000.0
        var peaks: [Double] = []
        var n = 1
        while true {
            let freq = Double(n) / delaySec
            if freq > maxFrequency { break }
            peaks.append(freq)
            n += 1
        }
        return peaks
    }

    /// Comb filter notch frequencies
    func combFilterNotches(delayMs: Double, maxFrequency: Double = 20000.0) -> [Double] {
        let delaySec = delayMs / 1000.0
        var notches: [Double] = []
        var n = 1
        while true {
            let freq = (Double(n) - 0.5) / delaySec
            if freq > maxFrequency { break }
            notches.append(freq)
            n += 1
        }
        return notches
    }

    // MARK: - Haas Effect (Stereo Width)

    /// Haas effect delay for stereo width (1-40ms)
    func haasDelay(widthAmount: Double) -> Double {
        let clamped = max(0.0, min(1.0, widthAmount))
        return 1.0 + clamped * 39.0
    }

    // MARK: - Real-Time Streaming Support

    /// Calculate latency compensation for network streaming
    struct StreamingLatency {
        let networkLatencyMs: Double
        let bufferLatencyMs: Double
        let processingLatencyMs: Double
        let totalLatencyMs: Double
        let compensationSamples: Int

        var isRealTimeCapable: Bool {
            totalLatencyMs < 30.0  // < 30ms considered "real-time"
        }
    }

    /// Calculate streaming latency compensation
    func calculateStreamingLatency(
        networkPingMs: Double,
        bufferSize: Int,
        sampleRate: Double,
        processingLatencyMs: Double = 5.0
    ) -> StreamingLatency {
        let networkLatency = networkPingMs / 2.0  // One-way latency
        let bufferLatency = Double(bufferSize) / sampleRate * 1000.0
        let total = networkLatency + bufferLatency + processingLatencyMs

        return StreamingLatency(
            networkLatencyMs: networkLatency,
            bufferLatencyMs: bufferLatency,
            processingLatencyMs: processingLatencyMs,
            totalLatencyMs: total,
            compensationSamples: Int(total * sampleRate / 1000.0)
        )
    }

    // MARK: - Initialization

    init() {
        recalculateTimings()
    }
}

// MARK: - Use Case Presets

extension EchoelStudioCalculator {

    /// Pre-configured settings for different use cases
    enum UseCase: String, CaseIterable, Identifiable {
        case studio = "Studio Production"
        case concert = "Concert/Live"
        case streaming = "Online Streaming"
        case collaboration = "Worldwide Collaboration"
        case school = "School/Education"
        case therapy = "Therapy/Health"
        case yoga = "Yoga/Movement"
        case theater = "Theater/Performance"
        case research = "Research/Science"

        var id: String { rawValue }

        /// Recommended settings for use case
        var settings: UseCaseSettings {
            switch self {
            case .studio:
                return UseCaseSettings(
                    bufferSize: 128,
                    sampleRate: 96000,
                    concertPitch: .a440,
                    latencyPriority: .quality,
                    description: "High-quality recording and mixing"
                )
            case .concert:
                return UseCaseSettings(
                    bufferSize: 64,
                    sampleRate: 48000,
                    concertPitch: .a442,
                    latencyPriority: .lowLatency,
                    description: "Live performance with minimal latency"
                )
            case .streaming:
                return UseCaseSettings(
                    bufferSize: 256,
                    sampleRate: 48000,
                    concertPitch: .a440,
                    latencyPriority: .balanced,
                    description: "Online streaming with good quality"
                )
            case .collaboration:
                return UseCaseSettings(
                    bufferSize: 256,
                    sampleRate: 48000,
                    concertPitch: .a440,
                    latencyPriority: .networkOptimized,
                    description: "Worldwide real-time collaboration"
                )
            case .school:
                return UseCaseSettings(
                    bufferSize: 512,
                    sampleRate: 44100,
                    concertPitch: .a440,
                    latencyPriority: .stable,
                    description: "Educational environment"
                )
            case .therapy:
                return UseCaseSettings(
                    bufferSize: 512,
                    sampleRate: 48000,
                    concertPitch: .a432,
                    latencyPriority: .quality,
                    description: "Therapeutic applications"
                )
            case .yoga:
                return UseCaseSettings(
                    bufferSize: 512,
                    sampleRate: 48000,
                    concertPitch: .a432,
                    latencyPriority: .stable,
                    description: "Yoga and movement practices"
                )
            case .theater:
                return UseCaseSettings(
                    bufferSize: 128,
                    sampleRate: 48000,
                    concertPitch: .a440,
                    latencyPriority: .lowLatency,
                    description: "Theater and performance"
                )
            case .research:
                return UseCaseSettings(
                    bufferSize: 64,
                    sampleRate: 96000,
                    concertPitch: .a440,
                    latencyPriority: .precision,
                    description: "Scientific research and measurement"
                )
            }
        }
    }

    struct UseCaseSettings {
        let bufferSize: Int
        let sampleRate: Int
        let concertPitch: ConcertPitch
        let latencyPriority: LatencyPriority
        let description: String
    }

    enum LatencyPriority: String {
        case lowLatency = "Low Latency"
        case quality = "Quality"
        case balanced = "Balanced"
        case stable = "Stable"
        case networkOptimized = "Network Optimized"
        case precision = "High Precision"
    }

    /// Apply use case preset
    func applyUseCase(_ useCase: UseCase) {
        let settings = useCase.settings
        selectedConcertPitch = settings.concertPitch
        useCustomPitch = false
    }
}

// MARK: - Interval Calculator

extension EchoelStudioCalculator {

    /// Musical intervals with frequency ratios
    enum Interval: String, CaseIterable {
        case unison = "Unison"
        case minorSecond = "Minor 2nd"
        case majorSecond = "Major 2nd"
        case minorThird = "Minor 3rd"
        case majorThird = "Major 3rd"
        case perfectFourth = "Perfect 4th"
        case tritone = "Tritone"
        case perfectFifth = "Perfect 5th"
        case minorSixth = "Minor 6th"
        case majorSixth = "Major 6th"
        case minorSeventh = "Minor 7th"
        case majorSeventh = "Major 7th"
        case octave = "Octave"

        /// Semitones from root
        var semitones: Int {
            switch self {
            case .unison: return 0
            case .minorSecond: return 1
            case .majorSecond: return 2
            case .minorThird: return 3
            case .majorThird: return 4
            case .perfectFourth: return 5
            case .tritone: return 6
            case .perfectFifth: return 7
            case .minorSixth: return 8
            case .majorSixth: return 9
            case .minorSeventh: return 10
            case .majorSeventh: return 11
            case .octave: return 12
            }
        }

        /// Equal temperament ratio
        var equalTemperamentRatio: Double {
            return pow(2.0, Double(semitones) / 12.0)
        }

        /// Just intonation ratio (where applicable)
        var justIntonationRatio: Double {
            switch self {
            case .unison: return 1.0 / 1.0
            case .minorSecond: return 16.0 / 15.0
            case .majorSecond: return 9.0 / 8.0
            case .minorThird: return 6.0 / 5.0
            case .majorThird: return 5.0 / 4.0
            case .perfectFourth: return 4.0 / 3.0
            case .tritone: return 45.0 / 32.0
            case .perfectFifth: return 3.0 / 2.0
            case .minorSixth: return 8.0 / 5.0
            case .majorSixth: return 5.0 / 3.0
            case .minorSeventh: return 9.0 / 5.0
            case .majorSeventh: return 15.0 / 8.0
            case .octave: return 2.0 / 1.0
            }
        }

        /// Cents in equal temperament
        var cents: Double {
            return Double(semitones) * 100.0
        }

        /// Difference between ET and JI in cents
        var justIntonationDeviation: Double {
            let etCents = cents
            let jiCents = 1200.0 * log2(justIntonationRatio)
            return jiCents - etCents
        }
    }

    /// Calculate interval frequency
    func intervalFrequency(baseFrequency: Double, interval: Interval, useJustIntonation: Bool = false) -> Double {
        let ratio = useJustIntonation ? interval.justIntonationRatio : interval.equalTemperamentRatio
        return baseFrequency * ratio
    }
}

// MARK: - Biometric Integration

extension EchoelStudioCalculator {

    /// Map heart rate to musical tempo
    func heartRateToTempo(_ heartRate: Double, smoothing: Double = 0.5) -> Double {
        // Direct mapping with optional scaling
        // Typical heart rate: 60-100 BPM
        // Musical tempo: 60-180 BPM typically

        let minHR: Double = 40.0
        let maxHR: Double = 180.0
        let minTempo: Double = 40.0
        let maxTempo: Double = 200.0

        let normalized = (heartRate - minHR) / (maxHR - minHR)
        let smoothed = pow(normalized, smoothing)
        return minTempo + smoothed * (maxTempo - minTempo)
    }

    /// Map HRV to resonance Q-factor
    func hrvToQFactor(_ hrvMs: Double) -> Double {
        // Higher HRV = higher Q = more resonant
        // Typical HRV: 20-100ms RMSSD
        let normalized = min(hrvMs / 100.0, 1.0)
        return 5.0 + normalized * 45.0  // Q from 5 to 50
    }

    /// Map coherence to tuning cents deviation
    func coherenceToTuningStability(_ coherence: Double) -> Double {
        // Higher coherence = more stable tuning (less micro-variation)
        // Returns max cents variation
        let normalized = coherence / 100.0
        return (1.0 - normalized) * 10.0  // 0-10 cents variation
    }

    /// Calculate resonance frequency from breath rate
    func breathToResonance(_ breathsPerMinute: Double) -> Double {
        // Breath rate to frequency
        return breathsPerMinute / 60.0
    }
}
