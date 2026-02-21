import Foundation
import Accelerate
import Combine

/// Real-Time Pitch Corrector — Professional Auto-Tune Engine
///
/// Features:
/// - Scale-aware pitch correction (snap to nearest note in key)
/// - Adjustable correction speed (0ms = hard-tune, 200ms+ = natural)
/// - Per-note bypass (exclude notes from correction)
/// - Humanize control (preserve natural pitch variation)
/// - Throat modeling (formant preservation during correction)
/// - MIDI note target mode (external pitch control)
/// - Flex-Tune style natural pitch response
///
/// Inspired by Antares Auto-Tune, Celemony Melodyne, Waves Tune
@MainActor
public class RealTimePitchCorrector: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentInputPitch: Float = 0       // Detected input Hz
    @Published var currentOutputPitch: Float = 0      // Corrected output Hz
    @Published var currentNote: String = ""           // e.g., "A4"
    @Published var centsDeviation: Float = 0          // Cents from target
    @Published var correctionAmount: Float = 0        // How much correction applied

    // MARK: - Correction Settings

    /// Musical key for correction (0 = C, 1 = C#, ... 11 = B)
    @Published var rootNote: Int = 0

    /// Scale type for note targeting
    @Published var scaleType: ScaleType = .chromatic

    /// Correction speed in milliseconds (0 = instant/hard-tune, 200+ = natural)
    @Published var correctionSpeed: Float = 50.0

    /// How aggressively to correct (0 = no correction, 1 = full snap)
    @Published var correctionStrength: Float = 0.8

    /// Humanize: preserve natural pitch micro-variations (0 = robotic, 1 = natural)
    @Published var humanize: Float = 0.2

    /// Flex-Tune threshold in cents — notes within this range aren't corrected
    @Published var flexTuneThreshold: Float = 10.0

    /// Per-note enable/disable (12 notes, true = correct, false = bypass)
    @Published var noteEnabled: [Bool] = Array(repeating: true, count: 12)

    /// Formant preservation during pitch shift
    @Published var preserveFormants: Bool = true

    /// Formant shift in semitones (independent of pitch)
    @Published var formantShift: Float = 0.0

    /// Reference tuning frequency (default A4 = 440 Hz)
    @Published var referenceA4: Float = 440.0

    /// Transpose output by semitones
    @Published var transpose: Int = 0

    /// Vibrato amount to add (0 = none, 1 = full)
    @Published var vibratoDepth: Float = 0.0
    @Published var vibratoRate: Float = 5.5  // Hz (typical singing vibrato)

    // MARK: - MIDI Target Mode

    @Published var midiTargetMode: Bool = false
    @Published var midiTargetNotes: Set<Int> = []  // Active MIDI note numbers

    // MARK: - Types

    public enum ScaleType: String, CaseIterable, Identifiable, Codable, Sendable {
        case chromatic = "Chromatic"
        case major = "Major"
        case naturalMinor = "Natural Minor"
        case harmonicMinor = "Harmonic Minor"
        case melodicMinor = "Melodic Minor"
        case pentatonicMajor = "Pentatonic Major"
        case pentatonicMinor = "Pentatonic Minor"
        case blues = "Blues"
        case dorian = "Dorian"
        case phrygian = "Phrygian"
        case lydian = "Lydian"
        case mixolydian = "Mixolydian"
        case locrian = "Locrian"
        case wholeTone = "Whole Tone"
        case diminished = "Diminished"
        case augmented = "Augmented"
        case arabian = "Arabian"
        case japanese = "Japanese"
        case hungarian = "Hungarian Minor"

        public var id: String { rawValue }

        /// Semitone intervals from root (C = 0)
        var intervals: [Int] {
            switch self {
            case .chromatic:       return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
            case .major:           return [0, 2, 4, 5, 7, 9, 11]
            case .naturalMinor:    return [0, 2, 3, 5, 7, 8, 10]
            case .harmonicMinor:   return [0, 2, 3, 5, 7, 8, 11]
            case .melodicMinor:    return [0, 2, 3, 5, 7, 9, 11]
            case .pentatonicMajor: return [0, 2, 4, 7, 9]
            case .pentatonicMinor: return [0, 3, 5, 7, 10]
            case .blues:           return [0, 3, 5, 6, 7, 10]
            case .dorian:          return [0, 2, 3, 5, 7, 9, 10]
            case .phrygian:        return [0, 1, 3, 5, 7, 8, 10]
            case .lydian:          return [0, 2, 4, 6, 7, 9, 11]
            case .mixolydian:      return [0, 2, 4, 5, 7, 9, 10]
            case .locrian:         return [0, 1, 3, 5, 6, 8, 10]
            case .wholeTone:       return [0, 2, 4, 6, 8, 10]
            case .diminished:      return [0, 2, 3, 5, 6, 8, 9, 11]
            case .augmented:       return [0, 3, 4, 7, 8, 11]
            case .arabian:         return [0, 2, 4, 5, 6, 8, 10]
            case .japanese:        return [0, 1, 5, 7, 8]
            case .hungarian:       return [0, 2, 3, 6, 7, 8, 11]
            }
        }
    }

    /// Detected note with pitch analysis
    struct DetectedNote {
        let frequency: Float          // Hz
        let midiNoteNumber: Float     // Fractional MIDI note (e.g., 69.5 = A4 + 50 cents)
        let noteName: String          // e.g., "A4"
        let centsFromTarget: Float    // -50 to +50
        let confidence: Float         // 0-1
        let isVoiced: Bool
    }

    /// Pitch correction target
    struct CorrectionTarget {
        let targetFrequency: Float
        let targetMidiNote: Int
        let correctionCents: Float
        let transitionTime: Float     // seconds to reach target
    }

    // MARK: - Internal State

    private let pitchDetector = PitchDetector()
    private let phaseVocoder: PhaseVocoder
    private let sampleRate: Float

    // Smoothing state
    private var smoothedPitchCorrection: Float = 0
    private var previousTargetNote: Int = -1
    private var noteTransitionProgress: Float = 1.0

    // Vibrato oscillator
    private var vibratoPhase: Float = 0.0

    // Pitch detection history for stability
    private var pitchHistory: [Float] = []
    private let pitchHistorySize = 5

    // Note names
    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - Initialization

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.phaseVocoder = PhaseVocoder(config: PhaseVocoder.Configuration(
            fftSize: 2048,
            hopSize: 512,
            sampleRate: sampleRate,
            preserveFormants: true
        ))
    }

    // MARK: - Public Processing API

    /// Process a block of audio with pitch correction
    /// - Parameter buffer: Input audio samples (mono)
    /// - Returns: Pitch-corrected audio samples
    func processBlock(_ buffer: [Float], sampleRate: Float) -> [Float] {
        guard buffer.count > 0 else { return buffer }

        // Detect pitch
        let detectedPitch = detectPitchFromSamples(buffer, sampleRate: sampleRate)
        guard detectedPitch > 50 && detectedPitch < 2000 else {
            return buffer  // No pitch detected or out of range
        }

        // Find correction target
        let target = findCorrectionTarget(inputFrequency: detectedPitch)

        // Calculate pitch shift in semitones
        let pitchShiftSemitones = target.correctionCents / 100.0

        // Apply smoothing based on correction speed
        let smoothedShift = smoothPitchShift(pitchShiftSemitones)

        // Skip if correction is negligible
        guard abs(smoothedShift) > 0.01 else { return buffer }

        // Apply pitch shift via phase vocoder
        return phaseVocoder.pitchShift(buffer, semitones: smoothedShift)
    }

    // MARK: - Pitch Detection

    /// Detect pitch from raw samples — delegates to shared PitchDetector (YIN)
    private func detectPitchFromSamples(_ samples: [Float], sampleRate: Float) -> Float {
        pitchDetector.detectPitch(samples: samples, sampleRate: sampleRate)
    }

    // MARK: - Note Finding

    /// Find the target note for correction
    func findCorrectionTarget(inputFrequency: Float) -> CorrectionTarget {
        // Convert frequency to MIDI note number (fractional)
        let midiNote = 69.0 + 12.0 * Foundation.log(inputFrequency / 440.0) / Foundation.log(2.0)

        // Get integer note and cents deviation
        let nearestMidi = Int(round(midiNote))
        let centsFromNearest = (midiNote - Float(nearestMidi)) * 100.0

        // Find target note in scale
        let targetMidi: Int
        if midiTargetMode && !midiTargetNotes.isEmpty {
            // MIDI target mode: snap to nearest active MIDI note
            targetMidi = findNearestMidiTarget(to: nearestMidi)
        } else {
            // Scale-based targeting
            targetMidi = findNearestScaleNote(midiNote: nearestMidi) + transpose
        }

        // Check if this note class is enabled
        let noteClass = ((targetMidi % 12) + 12) % 12
        guard noteEnabled[noteClass] else {
            // Note bypassed — return no correction
            return CorrectionTarget(
                targetFrequency: inputFrequency,
                targetMidiNote: nearestMidi,
                correctionCents: 0,
                transitionTime: 0
            )
        }

        // Calculate correction in cents
        let targetMidiFloat = Float(targetMidi)
        var correctionCents = (targetMidiFloat - midiNote) * 100.0

        // Apply Flex-Tune: reduce correction near the target
        if abs(centsFromNearest) < flexTuneThreshold && targetMidi == nearestMidi {
            correctionCents *= max(0, (abs(centsFromNearest) - flexTuneThreshold / 2.0)) / (flexTuneThreshold / 2.0)
        }

        // Apply strength
        correctionCents *= correctionStrength

        // Apply humanize (reduce correction by random micro-amount)
        if humanize > 0 {
            let randomOffset = Float.random(in: -3...3) * humanize
            correctionCents += randomOffset
        }

        // Target frequency
        let targetFreq = 440.0 * pow(2.0, (targetMidiFloat - 69.0) / 12.0)

        // Transition time based on correction speed
        let transitionTime = correctionSpeed / 1000.0

        return CorrectionTarget(
            targetFrequency: targetFreq,
            targetMidiNote: targetMidi,
            correctionCents: correctionCents,
            transitionTime: transitionTime
        )
    }

    /// Find nearest note in the current scale
    private func findNearestScaleNote(midiNote: Int) -> Int {
        let noteClass = ((midiNote % 12) + 12) % 12
        let octave = (midiNote - noteClass) // MIDI note at octave start

        let scaleNotes = scaleType.intervals.map { (($0 + rootNote) % 12 + 12) % 12 }

        // Find nearest scale note
        var bestDistance = Int.max
        var bestNote = midiNote

        for scaleNote in scaleNotes {
            let distance = min(abs(noteClass - scaleNote), 12 - abs(noteClass - scaleNote))
            if distance < bestDistance {
                bestDistance = distance
                // Choose the closest direction
                let diff = scaleNote - noteClass
                if abs(diff) <= 6 {
                    bestNote = octave + scaleNote
                } else if diff > 0 {
                    bestNote = octave + scaleNote - 12
                } else {
                    bestNote = octave + scaleNote + 12
                }
            }
        }

        return bestNote
    }

    /// Find nearest MIDI target note
    private func findNearestMidiTarget(to midiNote: Int) -> Int {
        var nearest = midiNote
        var minDist = Int.max
        for target in midiTargetNotes {
            let dist = abs(target - midiNote)
            if dist < minDist {
                minDist = dist
                nearest = target
            }
        }
        return nearest
    }

    // MARK: - Smoothing

    /// Smooth pitch correction for natural transitions
    private func smoothPitchShift(_ targetShift: Float) -> Float {
        // Simple exponential smoothing
        // correctionSpeed: 0ms = instant, higher = slower
        let alpha: Float
        if correctionSpeed <= 0 {
            alpha = 1.0  // Instant
        } else {
            // Time constant based on block size (~10ms)
            let blockTime: Float = 0.01
            alpha = min(1.0, blockTime / (correctionSpeed / 1000.0))
        }

        smoothedPitchCorrection += (targetShift - smoothedPitchCorrection) * alpha
        return smoothedPitchCorrection
    }

    // MARK: - Utility

    /// Convert MIDI note number to note name
    static func midiToNoteName(_ midi: Int) -> String {
        let noteClass = ((midi % 12) + 12) % 12
        let octave = (midi / 12) - 1
        return "\(noteNames[noteClass])\(octave)"
    }

    /// Convert frequency to MIDI note number
    static func frequencyToMidi(_ freq: Float) -> Float {
        guard freq > 0 else { return 0 }
        return 69.0 + 12.0 * Foundation.log(freq / 440.0) / Foundation.log(2.0)
    }

    /// Convert MIDI note to frequency
    static func midiToFrequency(_ midi: Float) -> Float {
        return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    /// Get all notes in current scale as MIDI note numbers (for one octave from root)
    func getScaleNotes() -> [Int] {
        return scaleType.intervals.map { ($0 + rootNote) % 12 }
    }
}
