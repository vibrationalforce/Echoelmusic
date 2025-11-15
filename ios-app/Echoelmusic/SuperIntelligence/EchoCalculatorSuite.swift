import Foundation
import AVFoundation
import Accelerate

// MARK: - EchoCalculator Suite
/// Professional studio calculation tools for audio production
/// Phase 6.3+: Enhanced Super Intelligence Tools
///
/// Tools:
/// 1. BPM Calculator - Tap tempo, beat detection
/// 2. Delay Calculator - BPM-synced delay times
/// 3. Reverb Calculator - Room size, decay time
/// 4. Frequency Calculator - Note to frequency, harmonics
/// 5. Loudness Calculator - LUFS, dynamic range
class EchoCalculatorSuite: ObservableObject {

    // MARK: - Published State
    @Published var currentBPM: Double = 120.0
    @Published var detectedKey: String = "C Major"
    @Published var recentCalculations: [CalculationResult] = []

    // MARK: - BPM Calculator

    struct TapTempoDetector {
        private var tapTimes: [Date] = []
        private let maxTaps = 8
        private let tapTimeout: TimeInterval = 2.0

        mutating func tap() -> Double? {
            let now = Date()

            // Clear old taps
            tapTimes = tapTimes.filter { now.timeIntervalSince($0) < tapTimeout }

            // Add new tap
            tapTimes.append(now)

            // Need at least 2 taps
            guard tapTimes.count >= 2 else { return nil }

            // Calculate intervals
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                let interval = tapTimes[i].timeIntervalSince(tapTimes[i-1])
                intervals.append(interval)
            }

            // Average interval
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

            // Convert to BPM (60 seconds / interval = beats per minute)
            let bpm = 60.0 / avgInterval

            return bpm
        }

        mutating func reset() {
            tapTimes.removeAll()
        }
    }

    // MARK: - Delay Calculator

    enum NoteDivision: String, CaseIterable {
        case whole = "1/1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtySecond = "1/32"

        var multiplier: Double {
            switch self {
            case .whole: return 4.0
            case .half: return 2.0
            case .quarter: return 1.0
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .thirtySecond: return 0.125
            }
        }
    }

    enum NoteModifier: String, CaseIterable {
        case straight = "Straight"
        case dotted = "Dotted"
        case triplet = "Triplet"

        var factor: Double {
            switch self {
            case .straight: return 1.0
            case .dotted: return 1.5
            case .triplet: return 2.0/3.0
            }
        }
    }

    static func calculateDelayTime(
        bpm: Double,
        division: NoteDivision,
        modifier: NoteModifier = .straight
    ) -> Double {
        // Formula: (60,000 ms / BPM) × note value × modifier
        let beatDuration = 60000.0 / bpm  // Quarter note in milliseconds
        let delayTime = beatDuration * division.multiplier * modifier.factor

        return delayTime
    }

    static func calculateAllDelayTimes(bpm: Double) -> [String: Double] {
        var results: [String: Double] = [:]

        for division in NoteDivision.allCases {
            for modifier in NoteModifier.allCases {
                let key = "\(division.rawValue) \(modifier.rawValue)"
                let time = calculateDelayTime(bpm: bpm, division: division, modifier: modifier)
                results[key] = time
            }
        }

        return results
    }

    // MARK: - Reverb Calculator

    struct ReverbParameters {
        var roomSize: Double           // meters (width × depth × height)
        var decayTime: Double          // seconds (RT60)
        var earlyReflections: Double   // milliseconds
        var predelay: Double           // milliseconds
        var damping: Double            // 0-1 (high frequency absorption)

        static func fromRoomDimensions(width: Double, depth: Double, height: Double) -> ReverbParameters {
            // Calculate room size in cubic meters
            let volume = width * depth * height

            // Estimate decay time based on room volume
            // Sabine's formula (simplified): RT60 ≈ 0.161 × V / A
            // Assuming average absorption coefficient of 0.2
            let surfaceArea = 2 * (width * depth + width * height + depth * height)
            let absorption = surfaceArea * 0.2
            let rt60 = 0.161 * volume / absorption

            // Estimate early reflections (first reflection time)
            let avgDimension = (width + depth + height) / 3.0
            let earlyReflections = (avgDimension / 343.0) * 1000.0  // Speed of sound: 343 m/s

            return ReverbParameters(
                roomSize: volume,
                decayTime: rt60,
                earlyReflections: earlyReflections,
                predelay: 20.0,  // Standard 20ms
                damping: 0.5
            )
        }

        // Common room presets
        static let smallRoom = fromRoomDimensions(width: 4, depth: 5, height: 2.5)
        static let mediumRoom = fromRoomDimensions(width: 8, depth: 10, height: 3.5)
        static let largeHall = fromRoomDimensions(width: 20, depth: 30, height: 10)
        static let cathedral = fromRoomDimensions(width: 40, depth: 60, height: 20)
    }

    // MARK: - Frequency Calculator

    static func noteToFrequency(note: String, octave: Int) -> Double {
        // MIDI note number calculation
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        guard let noteIndex = noteNames.firstIndex(of: note.uppercased()) else {
            return 440.0  // Default to A4
        }

        let midiNote = (octave + 1) * 12 + noteIndex
        // A4 = MIDI 69 = 440 Hz
        let frequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)

        return frequency
    }

    static func frequencyToNote(frequency: Double) -> (note: String, octave: Int, cents: Double) {
        // Convert frequency to MIDI note number
        let midiNote = 69.0 + 12.0 * log2(frequency / 440.0)
        let roundedMidi = round(midiNote)

        // Calculate cents deviation
        let cents = (midiNote - roundedMidi) * 100.0

        // Convert MIDI to note name and octave
        let noteIndex = Int(roundedMidi) % 12
        let octave = Int(roundedMidi) / 12 - 1

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[noteIndex]

        return (noteName, octave, cents)
    }

    static func calculateHarmonics(fundamental: Double, count: Int = 8) -> [Double] {
        var harmonics: [Double] = []

        for i in 1...count {
            harmonics.append(fundamental * Double(i))
        }

        return harmonics
    }

    // MARK: - Loudness Calculator

    /// Calculates LUFS (Loudness Units relative to Full Scale)
    /// ITU-R BS.1770-4 standard
    static func calculateLUFS(from buffer: AVAudioPCMBuffer) -> Double {
        guard let floatData = buffer.floatChannelData?[0] else { return -100.0 }
        let frameCount = Int(buffer.frameLength)

        // K-weighting filter coefficients (ITU-R BS.1770)
        // Stage 1: High-shelf filter (+4dB at high frequencies)
        // Stage 2: High-pass filter (RLB filter)

        // Simplified LUFS calculation (proper implementation would use full K-weighting)

        // Calculate RMS power
        var sumSquares: Float = 0.0
        vDSP_svesq(floatData, 1, &sumSquares, vDSP_Length(frameCount))

        let rms = sqrt(sumSquares / Float(frameCount))

        // Convert to LUFS (integrated loudness)
        // LUFS = -0.691 + 10 × log10(sum of mean squares)
        let lufs = -0.691 + 10.0 * log10(Double(rms * rms))

        return lufs
    }

    static func calculateDynamicRange(from buffer: AVAudioPCMBuffer) -> Double {
        guard let floatData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameCount = Int(buffer.frameLength)

        // Find peak
        var peak: Float = 0.0
        vDSP_maxmgv(floatData, 1, &peak, vDSP_Length(frameCount))

        // Calculate RMS
        var sumSquares: Float = 0.0
        vDSP_svesq(floatData, 1, &sumSquares, vDSP_Length(frameCount))
        let rms = sqrt(sumSquares / Float(frameCount))

        // Dynamic range in dB
        let peakDB = 20.0 * log10(Double(peak))
        let rmsDB = 20.0 * log10(Double(rms))
        let dynamicRange = peakDB - rmsDB

        return dynamicRange
    }

    static func calculateCrestFactor(from buffer: AVAudioPCMBuffer) -> Double {
        guard let floatData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameCount = Int(buffer.frameLength)

        // Peak
        var peak: Float = 0.0
        vDSP_maxmgv(floatData, 1, &peak, vDSP_Length(frameCount))

        // RMS
        var sumSquares: Float = 0.0
        vDSP_svesq(floatData, 1, &sumSquares, vDSP_Length(frameCount))
        let rms = sqrt(sumSquares / Float(frameCount))

        // Crest factor (peak / RMS)
        let crestFactor = Double(peak / rms)

        return crestFactor
    }

    // MARK: - Mix Calculator

    static func calculatePanLaw(pan: Double, law: PanLaw = .constant) -> (left: Double, right: Double) {
        // Pan: -1.0 (left) to 1.0 (right)
        let angle = (pan + 1.0) * .pi / 4.0  // 0 to π/2

        switch law {
        case .constant:
            // Constant power panning
            return (cos(angle), sin(angle))

        case .linear:
            // Linear panning
            let left = 1.0 - (pan + 1.0) / 2.0
            let right = (pan + 1.0) / 2.0
            return (left, right)

        case .minus3dB:
            // -3dB center pan law
            let left = cos(angle) * sqrt(2.0)
            let right = sin(angle) * sqrt(2.0)
            return (min(1.0, left), min(1.0, right))

        case .minus6dB:
            // -6dB center pan law
            let left = 1.0 - (pan + 1.0) / 2.0
            let right = (pan + 1.0) / 2.0
            return (left * 1.414, right * 1.414)
        }
    }

    enum PanLaw {
        case constant      // Constant power (default)
        case linear        // Linear panning
        case minus3dB      // -3dB center
        case minus6dB      // -6dB center
    }

    // MARK: - Sample Rate Calculator

    static func calculateNyquistFrequency(sampleRate: Double) -> Double {
        return sampleRate / 2.0
    }

    static func calculateMaximumFrequencyResolution(fftSize: Int, sampleRate: Double) -> Double {
        return sampleRate / Double(fftSize)
    }

    static func calculateLatency(bufferSize: Int, sampleRate: Double) -> Double {
        // Latency in milliseconds
        return (Double(bufferSize) / sampleRate) * 1000.0
    }

    // MARK: - Time Conversion

    static func samplesToMilliseconds(samples: Int64, sampleRate: Double) -> Double {
        return (Double(samples) / sampleRate) * 1000.0
    }

    static func millisecondsToSamples(ms: Double, sampleRate: Double) -> Int64 {
        return Int64((ms / 1000.0) * sampleRate)
    }

    static func samplesToBeats(samples: Int64, sampleRate: Double, bpm: Double) -> Double {
        let seconds = Double(samples) / sampleRate
        let beats = seconds * (bpm / 60.0)
        return beats
    }

    static func beatsToSamples(beats: Double, sampleRate: Double, bpm: Double) -> Int64 {
        let seconds = beats * (60.0 / bpm)
        let samples = Int64(seconds * sampleRate)
        return samples
    }

    // MARK: - Result Storage

    struct CalculationResult: Identifiable {
        let id = UUID()
        let type: CalculationType
        let input: String
        let output: String
        let timestamp: Date

        enum CalculationType: String {
            case bpm = "BPM"
            case delay = "Delay Time"
            case reverb = "Reverb"
            case frequency = "Frequency"
            case loudness = "Loudness"
            case mix = "Mix"
        }
    }

    func recordCalculation(_ result: CalculationResult) {
        recentCalculations.insert(result, at: 0)
        if recentCalculations.count > 20 {
            recentCalculations.removeLast()
        }
    }
}

// MARK: - Quick Access Extensions

extension EchoCalculatorSuite {

    /// Quick delay time calculation (most common use case)
    static func quickDelay(_ bpm: Double, _ division: NoteDivision) -> Double {
        return calculateDelayTime(bpm: bpm, division: division)
    }

    /// Quick note to frequency
    static func freq(_ note: String, _ octave: Int = 4) -> Double {
        return noteToFrequency(note: note, octave: octave)
    }

    /// Quick BPM from delay time
    static func bpmFromDelay(_ delayMs: Double, division: NoteDivision = .quarter) -> Double {
        // Reverse calculation: BPM = 60000 / (delay / (division × modifier))
        return 60000.0 / (delayMs / division.multiplier)
    }
}

// MARK: - Common Music Theory Constants

extension EchoCalculatorSuite {

    static let concertPitch: Double = 440.0  // A4

    static let commonScales: [String: [Int]] = [
        "Major": [0, 2, 4, 5, 7, 9, 11],
        "Natural Minor": [0, 2, 3, 5, 7, 8, 10],
        "Harmonic Minor": [0, 2, 3, 5, 7, 8, 11],
        "Melodic Minor": [0, 2, 3, 5, 7, 9, 11],
        "Pentatonic Major": [0, 2, 4, 7, 9],
        "Pentatonic Minor": [0, 3, 5, 7, 10],
        "Blues": [0, 3, 5, 6, 7, 10],
        "Chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    ]

    static let commonChords: [String: [Int]] = [
        "Major": [0, 4, 7],
        "Minor": [0, 3, 7],
        "Diminished": [0, 3, 6],
        "Augmented": [0, 4, 8],
        "Major 7": [0, 4, 7, 11],
        "Minor 7": [0, 3, 7, 10],
        "Dominant 7": [0, 4, 7, 10],
        "Diminished 7": [0, 3, 6, 9]
    ]

    static let healingFrequencies: [String: Double] = [
        "Solfeggio 396 Hz": 396.0,   // Liberation from fear
        "Solfeggio 417 Hz": 417.0,   // Facilitating change
        "Solfeggio 528 Hz": 528.0,   // Transformation & miracles (DNA repair)
        "Solfeggio 639 Hz": 639.0,   // Connecting & relationships
        "Solfeggio 741 Hz": 741.0,   // Awakening intuition
        "Solfeggio 852 Hz": 852.0,   // Returning to spiritual order
        "Schumann Resonance": 7.83,  // Earth's electromagnetic field
        "Alpha Waves": 10.0,         // Relaxation
        "Theta Waves": 6.0,          // Meditation
        "Delta Waves": 2.0           // Deep sleep
    ]
}
