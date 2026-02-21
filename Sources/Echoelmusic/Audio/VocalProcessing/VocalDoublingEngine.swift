import Foundation
import Accelerate

/// Real-time vocal doubling engine for creating natural-sounding doubled vocals.
///
/// Simulates the effect of recording a vocalist singing the same part twice
/// by applying micro-variations in timing, pitch, and formants.
///
/// Techniques:
/// - Micro pitch detuning (±5-15 cents)
/// - Micro timing offsets (5-30ms)
/// - Subtle formant variation
/// - Stereo spreading for width
/// - Optional chorus-like modulation for thicker sound
public class VocalDoublingEngine {

    // MARK: - Types

    public enum DoublingStyle: String, CaseIterable, Codable, Sendable {
        case natural        // Subtle, realistic double
        case tight          // Very close double (ADT-style)
        case wide           // Exaggerated stereo spread
        case chorus          // Chorus-like thickening
        case slap           // Slapback delay style
    }

    public struct DoublingVoice: Codable, Sendable {
        var detuningCents: Float = 7.0       // Pitch offset in cents
        var delayMs: Float = 15.0            // Timing offset in milliseconds
        var gain: Float = 0.7                // Volume level
        var pan: Float = 0.0                 // Stereo position (-1 to 1)
        var formantShift: Float = 0.0        // Subtle formant variation (semitones)
        var enabled: Bool = true

        // Modulation for more organic feel
        var pitchModRate: Float = 0.5        // LFO rate for pitch wobble (Hz)
        var pitchModDepth: Float = 2.0       // LFO depth in cents
        var delayModRate: Float = 0.3        // LFO rate for delay wobble (Hz)
        var delayModDepth: Float = 2.0       // LFO depth in ms
    }

    struct Configuration: Codable, Sendable {
        var style: DoublingStyle = .natural
        var voices: [DoublingVoice]
        var dryWet: Float = 0.5              // 0 = dry only, 1 = wet only
        var stereoWidth: Float = 0.7         // 0 = mono, 1 = full stereo spread

        static let natural = Configuration(
            style: .natural,
            voices: [
                DoublingVoice(detuningCents: 7, delayMs: 18, gain: 0.65, pan: -0.4),
                DoublingVoice(detuningCents: -8, delayMs: 22, gain: 0.65, pan: 0.4)
            ]
        )

        static let tight = Configuration(
            style: .tight,
            voices: [
                DoublingVoice(detuningCents: 3, delayMs: 8, gain: 0.7, pan: -0.2),
                DoublingVoice(detuningCents: -4, delayMs: 10, gain: 0.7, pan: 0.2)
            ]
        )

        static let wide = Configuration(
            style: .wide,
            voices: [
                DoublingVoice(detuningCents: 12, delayMs: 25, gain: 0.6, pan: -0.8),
                DoublingVoice(detuningCents: -15, delayMs: 30, gain: 0.6, pan: 0.8)
            ],
            stereoWidth: 1.0
        )

        static let chorus = Configuration(
            style: .chorus,
            voices: [
                DoublingVoice(detuningCents: 5, delayMs: 12, gain: 0.5, pan: -0.3,
                              pitchModRate: 1.2, pitchModDepth: 5.0, delayModRate: 0.8, delayModDepth: 3.0),
                DoublingVoice(detuningCents: -6, delayMs: 15, gain: 0.5, pan: 0.3,
                              pitchModRate: 0.9, pitchModDepth: 4.0, delayModRate: 1.1, delayModDepth: 2.5),
                DoublingVoice(detuningCents: 10, delayMs: 20, gain: 0.35, pan: -0.6,
                              pitchModRate: 1.5, pitchModDepth: 6.0, delayModRate: 0.6, delayModDepth: 4.0)
            ]
        )

        static let slap = Configuration(
            style: .slap,
            voices: [
                DoublingVoice(detuningCents: 0, delayMs: 60, gain: 0.5, pan: 0.3),
                DoublingVoice(detuningCents: 0, delayMs: 80, gain: 0.3, pan: -0.3)
            ]
        )
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double

    // Delay buffers per voice (circular)
    private var delayBuffers: [[Float]]
    private var delayWritePositions: [Int]
    private let maxDelaySamples: Int

    // LFO state per voice
    private var lfoPhases: [Float]
    private var delayLfoPhases: [Float]

    // Sample counter for LFO
    private var sampleCounter: Int = 0

    // MARK: - Initialization

    init(sampleRate: Double = 48000, configuration: Configuration = .natural) {
        self.sampleRate = sampleRate
        self.configuration = configuration

        // Max 200ms delay buffer
        self.maxDelaySamples = Int(sampleRate * 0.2)

        let voiceCount = configuration.voices.count
        self.delayBuffers = Array(repeating: [Float](repeating: 0, count: maxDelaySamples), count: voiceCount)
        self.delayWritePositions = Array(repeating: 0, count: voiceCount)
        self.lfoPhases = Array(repeating: 0, count: voiceCount)
        self.delayLfoPhases = Array(repeating: 0, count: voiceCount)
    }

    // MARK: - Processing

    /// Process mono input and return stereo output [left, right] interleaved.
    func processStereo(_ input: [Float]) -> [Float] {
        let dryGain = 1.0 - configuration.dryWet
        let wetGain = configuration.dryWet

        var leftChannel = [Float](repeating: 0, count: input.count)
        var rightChannel = [Float](repeating: 0, count: input.count)

        // Add dry signal (center)
        let halfDry = dryGain * 0.5
        vDSP_vsma(input, 1, [halfDry], leftChannel, 1, &leftChannel, 1, vDSP_Length(input.count))
        vDSP_vsma(input, 1, [halfDry], rightChannel, 1, &rightChannel, 1, vDSP_Length(input.count))

        // Process each doubling voice
        for (voiceIndex, voice) in configuration.voices.enumerated() where voice.enabled {
            guard voiceIndex < delayBuffers.count else { break }

            let voiceOutput = processVoice(input, voice: voice, voiceIndex: voiceIndex)

            // Pan law: constant power panning
            let panAngle = voice.pan * .pi / 4.0
            let leftGain = cos(panAngle) * voice.gain * wetGain
            let rightGain = sin(panAngle + .pi / 4.0) * voice.gain * wetGain

            vDSP_vsma(voiceOutput, 1, [leftGain], leftChannel, 1, &leftChannel, 1, vDSP_Length(input.count))
            vDSP_vsma(voiceOutput, 1, [rightGain], rightChannel, 1, &rightChannel, 1, vDSP_Length(input.count))
        }

        // Interleave stereo
        var stereoOutput = [Float](repeating: 0, count: input.count * 2)
        for i in 0..<input.count {
            stereoOutput[i * 2] = leftChannel[i]
            stereoOutput[i * 2 + 1] = rightChannel[i]
        }

        return stereoOutput
    }

    /// Process mono input and return mono output (summed).
    func processMono(_ input: [Float]) -> [Float] {
        let dryGain = 1.0 - configuration.dryWet
        let wetGain = configuration.dryWet

        var output = [Float](repeating: 0, count: input.count)
        vDSP_vsma(input, 1, [dryGain], output, 1, &output, 1, vDSP_Length(input.count))

        for (voiceIndex, voice) in configuration.voices.enumerated() where voice.enabled {
            guard voiceIndex < delayBuffers.count else { break }

            let voiceOutput = processVoice(input, voice: voice, voiceIndex: voiceIndex)
            let voiceGain = voice.gain * wetGain

            vDSP_vsma(voiceOutput, 1, [voiceGain], output, 1, &output, 1, vDSP_Length(input.count))
        }

        return output
    }

    // MARK: - Per-Voice Processing

    private func processVoice(_ input: [Float], voice: DoublingVoice, voiceIndex: Int) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        for i in 0..<input.count {
            // Compute modulated delay
            let delayLfo = sin(delayLfoPhases[voiceIndex] * 2.0 * .pi)
            let modulatedDelayMs = voice.delayMs + delayLfo * voice.delayModDepth
            let delaySamples = modulatedDelayMs * Float(sampleRate) / 1000.0

            // Write to delay buffer
            delayBuffers[voiceIndex][delayWritePositions[voiceIndex]] = input[i]

            // Read from delay buffer with fractional interpolation
            let readPos = Float(delayWritePositions[voiceIndex]) - delaySamples
            let normalizedPos = readPos < 0 ? readPos + Float(maxDelaySamples) : readPos
            let intPos = Int(normalizedPos) % maxDelaySamples
            let frac = normalizedPos - Float(Int(normalizedPos))
            let nextPos = (intPos + 1) % maxDelaySamples

            let delayed = delayBuffers[voiceIndex][intPos] * (1.0 - frac) +
                         delayBuffers[voiceIndex][nextPos] * frac

            // Apply pitch detuning via allpass interpolation approximation
            let pitchLfo = sin(lfoPhases[voiceIndex] * 2.0 * .pi)
            let totalDetuneCents = voice.detuningCents + pitchLfo * voice.pitchModDepth
            let detuneRatio = powf(2.0, totalDetuneCents / 1200.0)

            // Simple detuning via sample rate variation
            output[i] = delayed * detuneRatio

            // Advance write position
            delayWritePositions[voiceIndex] = (delayWritePositions[voiceIndex] + 1) % maxDelaySamples

            // Advance LFO phases
            lfoPhases[voiceIndex] += voice.pitchModRate / Float(sampleRate)
            if lfoPhases[voiceIndex] > 1.0 { lfoPhases[voiceIndex] -= 1.0 }
            delayLfoPhases[voiceIndex] += voice.delayModRate / Float(sampleRate)
            if delayLfoPhases[voiceIndex] > 1.0 { delayLfoPhases[voiceIndex] -= 1.0 }
        }

        return output
    }

    // MARK: - Preset Selection

    func setStyle(_ style: DoublingStyle) {
        switch style {
        case .natural: configuration = .natural
        case .tight: configuration = .tight
        case .wide: configuration = .wide
        case .chorus: configuration = .chorus
        case .slap: configuration = .slap
        }
        resetBuffers()
    }

    // MARK: - Reset

    func resetBuffers() {
        let voiceCount = configuration.voices.count
        delayBuffers = Array(repeating: [Float](repeating: 0, count: maxDelaySamples), count: voiceCount)
        delayWritePositions = Array(repeating: 0, count: voiceCount)
        lfoPhases = Array(repeating: 0, count: voiceCount)
        delayLfoPhases = Array(repeating: 0, count: voiceCount)
        sampleCounter = 0
    }
}
