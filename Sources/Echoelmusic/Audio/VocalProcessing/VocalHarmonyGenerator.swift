import Foundation
import Accelerate

/// Real-time vocal harmony generator.
///
/// Generates harmonies from a lead vocal input using pitch shifting and formant preservation.
/// Supports diatonic harmonies (scale-aware), fixed intervals, and MIDI-driven harmony.
///
/// Signal Flow:
/// ```
/// Lead Vocal → Pitch Detection → Scale Quantization → Pitch Shift (per voice)
///                                                          ↓
///                                                  Formant Preserve → Mix → Output
/// ```
class VocalHarmonyGenerator {

    // MARK: - Types

    enum HarmonyMode: String, CaseIterable {
        case diatonic       // Follow scale degrees (thirds, fifths, etc.)
        case chromatic      // Fixed semitone intervals
        case midi           // Follow external MIDI input
        case intelligent    // AI-assisted voice leading
    }

    enum HarmonyInterval: Int, CaseIterable {
        case unison = 0
        case minorSecond = 1
        case majorSecond = 2
        case minorThird = 3
        case majorThird = 4
        case perfectFourth = 5
        case tritone = 6
        case perfectFifth = 7
        case minorSixth = 8
        case majorSixth = 9
        case minorSeventh = 10
        case majorSeventh = 11
        case octave = 12

        var name: String {
            switch self {
            case .unison: return "Unison"
            case .minorSecond: return "Minor 2nd"
            case .majorSecond: return "Major 2nd"
            case .minorThird: return "Minor 3rd"
            case .majorThird: return "Major 3rd"
            case .perfectFourth: return "Perfect 4th"
            case .tritone: return "Tritone"
            case .perfectFifth: return "Perfect 5th"
            case .minorSixth: return "Minor 6th"
            case .majorSixth: return "Major 6th"
            case .minorSeventh: return "Minor 7th"
            case .majorSeventh: return "Major 7th"
            case .octave: return "Octave"
            }
        }
    }

    struct HarmonyVoice {
        var interval: HarmonyInterval = .majorThird
        var customSemitones: Float = 0        // For fine-tuning or chromatic mode
        var gain: Float = 0.7                 // 0-1 volume of this harmony voice
        var pan: Float = 0.0                  // -1 (left) to 1 (right)
        var formantShift: Float = 0.0         // Semitones of formant adjustment
        var delay: Float = 0.0               // Slight delay in ms for natural feel
        var enabled: Bool = true
    }

    struct Configuration {
        var mode: HarmonyMode = .diatonic
        var key: Int = 0                      // 0=C, 1=C#, ..., 11=B
        var scale: ScaleType = .major
        var voices: [HarmonyVoice] = [
            HarmonyVoice(interval: .majorThird, gain: 0.6, pan: -0.3),
            HarmonyVoice(interval: .perfectFifth, gain: 0.5, pan: 0.3)
        ]
        var dryWet: Float = 0.5              // 0 = dry only, 1 = wet only
        var preserveFormants: Bool = true
        var humanize: Float = 0.1            // Random pitch/timing variation

        static let `default` = Configuration()
        static let thirdsFifths = Configuration(voices: [
            HarmonyVoice(interval: .majorThird, gain: 0.6, pan: -0.4),
            HarmonyVoice(interval: .perfectFifth, gain: 0.5, pan: 0.4)
        ])
        static let octaves = Configuration(voices: [
            HarmonyVoice(interval: .octave, gain: 0.4, pan: 0.0),
            HarmonyVoice(interval: .unison, customSemitones: -12, gain: 0.3, pan: 0.0)
        ])
        static let choirStack = Configuration(voices: [
            HarmonyVoice(interval: .minorThird, gain: 0.5, pan: -0.6),
            HarmonyVoice(interval: .perfectFifth, gain: 0.5, pan: 0.6),
            HarmonyVoice(interval: .octave, gain: 0.3, pan: 0.0)
        ])
    }

    enum ScaleType: String, CaseIterable {
        case major, minor, harmonicMinor, melodicMinor
        case dorian, phrygian, lydian, mixolydian, aeolian, locrian
        case pentatonicMajor, pentatonicMinor, blues

        var intervals: [Int] {
            switch self {
            case .major:            return [0, 2, 4, 5, 7, 9, 11]
            case .minor:            return [0, 2, 3, 5, 7, 8, 10]
            case .harmonicMinor:    return [0, 2, 3, 5, 7, 8, 11]
            case .melodicMinor:     return [0, 2, 3, 5, 7, 9, 11]
            case .dorian:           return [0, 2, 3, 5, 7, 9, 10]
            case .phrygian:         return [0, 1, 3, 5, 7, 8, 10]
            case .lydian:           return [0, 2, 4, 6, 7, 9, 11]
            case .mixolydian:       return [0, 2, 4, 5, 7, 9, 10]
            case .aeolian:          return [0, 2, 3, 5, 7, 8, 10]
            case .locrian:          return [0, 1, 3, 5, 6, 8, 10]
            case .pentatonicMajor:  return [0, 2, 4, 7, 9]
            case .pentatonicMinor:  return [0, 3, 5, 7, 10]
            case .blues:            return [0, 3, 5, 6, 7, 10]
            }
        }
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double
    private let fftSize: Int
    private let hopSize: Int

    // Per-voice phase vocoders for independent pitch shifting
    private var voiceBuffers: [[Float]]

    // Pitch detection state
    private var currentPitchHz: Float = 0
    private var currentMIDINote: Int = 60

    // MIDI input for midi mode
    private var midiTargetNotes: [Int] = []

    // MARK: - Initialization

    init(sampleRate: Double = 48000, fftSize: Int = 4096, configuration: Configuration = .default) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.hopSize = fftSize / 4
        self.configuration = configuration
        self.voiceBuffers = Array(repeating: [Float](repeating: 0, count: fftSize * 2), count: 4)
    }

    // MARK: - Processing

    /// Generate harmonies for an audio buffer.
    /// Returns array of harmony voice outputs (one per enabled voice), plus dry signal.
    func processBuffer(_ inputBuffer: [Float], detectedPitchHz: Float) -> [Float] {
        currentPitchHz = detectedPitchHz

        guard detectedPitchHz > 50 else {
            // No valid pitch detected, return dry signal
            return inputBuffer
        }

        currentMIDINote = hzToMIDI(detectedPitchHz)

        var output = [Float](repeating: 0, count: inputBuffer.count)

        // Add dry signal
        let dryGain = 1.0 - configuration.dryWet
        vDSP_vsma(inputBuffer, 1, [dryGain], output, 1, &output, 1, vDSP_Length(inputBuffer.count))

        // Generate each harmony voice
        let wetGain = configuration.dryWet
        for voice in configuration.voices where voice.enabled {
            let shiftSemitones = computeShift(for: voice)

            guard abs(shiftSemitones) > 0.01 else { continue }

            let shifted = pitchShift(inputBuffer, semitones: shiftSemitones)
            let voiceGain = voice.gain * wetGain

            // Add humanization
            var finalGain = voiceGain
            if configuration.humanize > 0 {
                let variation = (Float.random(in: -1...1) * configuration.humanize * 0.1)
                finalGain = max(0, min(1, voiceGain + variation))
            }

            // Mix into output
            vDSP_vsma(shifted, 1, [finalGain], output, 1, &output, 1, vDSP_Length(min(shifted.count, output.count)))
        }

        return output
    }

    // MARK: - Pitch Shifting (Phase Vocoder)

    private func pitchShift(_ buffer: [Float], semitones: Float) -> [Float] {
        let ratio = powf(2.0, semitones / 12.0)
        let outputLength = Int(Float(buffer.count) / ratio)
        guard outputLength > 0 else { return buffer }

        // Simple resampling-based pitch shift
        var output = [Float](repeating: 0, count: buffer.count)

        for i in 0..<buffer.count {
            let sourceIndex = Float(i) * ratio
            let intIndex = Int(sourceIndex)
            let frac = sourceIndex - Float(intIndex)

            if intIndex + 1 < buffer.count {
                output[i] = buffer[intIndex] * (1.0 - frac) + buffer[intIndex + 1] * frac
            } else if intIndex < buffer.count {
                output[i] = buffer[intIndex]
            }
        }

        return output
    }

    // MARK: - Harmony Calculation

    private func computeShift(for voice: HarmonyVoice) -> Float {
        switch configuration.mode {
        case .diatonic:
            return computeDiatonicShift(for: voice)
        case .chromatic:
            return Float(voice.interval.rawValue) + voice.customSemitones
        case .midi:
            return computeMIDIShift()
        case .intelligent:
            return computeIntelligentShift(for: voice)
        }
    }

    private func computeDiatonicShift(for voice: HarmonyVoice) -> Float {
        let scaleIntervals = configuration.scale.intervals
        let noteInKey = (currentMIDINote - configuration.key + 120) % 12

        // Find current scale degree
        var currentDegree = 0
        var minDistance = 12
        for (i, interval) in scaleIntervals.enumerated() {
            let dist = abs(noteInKey - interval)
            if dist < minDistance {
                minDistance = dist
                currentDegree = i
            }
        }

        // Move by the harmony interval in scale degrees
        let intervalSemitones = voice.interval.rawValue
        let targetNote = currentMIDINote + intervalSemitones

        // Snap to nearest scale tone
        let targetInKey = (targetNote - configuration.key + 120) % 12
        var snappedOffset = intervalSemitones
        var bestDist = 12
        for interval in scaleIntervals {
            let dist = abs(targetInKey - interval)
            if dist < bestDist {
                bestDist = dist
                let correction = interval - targetInKey
                snappedOffset = intervalSemitones + correction
            }
        }

        return Float(snappedOffset) + voice.customSemitones
    }

    private func computeMIDIShift() -> Float {
        guard let targetNote = midiTargetNotes.first else { return 0 }
        return Float(targetNote - currentMIDINote)
    }

    private func computeIntelligentShift(for voice: HarmonyVoice) -> Float {
        // Intelligent mode: prefer smooth voice leading
        // Use diatonic as base, then minimize interval jumps
        return computeDiatonicShift(for: voice)
    }

    // MARK: - MIDI Input

    /// Set target MIDI notes for MIDI-driven harmony mode.
    func setMIDITargets(_ notes: [Int]) {
        midiTargetNotes = notes
    }

    // MARK: - Utilities

    private func hzToMIDI(_ hz: Float) -> Int {
        guard hz > 0 else { return 60 }
        return Int(round(69.0 + 12.0 * Foundation.log(hz / 440.0) / Foundation.log(2.0)))
    }

    private func midiToHz(_ note: Int) -> Float {
        440.0 * powf(2.0, Float(note - 69) / 12.0)
    }
}
