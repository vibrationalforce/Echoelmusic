import Foundation
import Accelerate

// MARK: - Choir Character Processor
// Advanced choir synthesis with realistic vocal modeling
// Supports: Cathedral, Gospel, Chamber, Boys, Orthodox, African, Nordic, etc.

public final class ChoirCharacterProcessor {

    // Choir-specific DSP components
    private var formantFilters: [FormantFilter] = []
    private var chorusEngine: ChoirChorusEngine
    private var reverbEngine: ChoirReverbEngine
    private var breathGenerator: BreathNoiseGenerator
    private var vibratoLFO: VibratoLFO

    // Voice ensemble simulation
    private var voiceEnsemble: VoiceEnsemble
    private var humanizer: VoiceHumanizer

    public init() {
        self.formantFilters = FormantFilter.createVowelSet()
        self.chorusEngine = ChoirChorusEngine()
        self.reverbEngine = ChoirReverbEngine()
        self.breathGenerator = BreathNoiseGenerator()
        self.vibratoLFO = VibratoLFO()
        self.voiceEnsemble = VoiceEnsemble()
        self.humanizer = VoiceHumanizer()
    }

    // MARK: - Main Processing

    public func process(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // 1. Apply formant shaping
        output = applyFormants(output, shift: params.formantShift)

        // 2. Add vibrato
        if params.vibrato > 0 {
            output = applyVibrato(output, depth: params.vibrato, rate: params.vibratoRate)
        }

        // 3. Add breathiness
        if params.breathiness > 0 {
            output = addBreathiness(output, amount: params.breathiness)
        }

        // 4. Apply warmth/brightness EQ
        output = applyToneShaping(output, warmth: params.warmth, brightness: params.brightness)

        // 5. Choir ensemble effect (multiple voices)
        if params.chorusAmount > 0 {
            output = applyChoirEnsemble(output, amount: params.chorusAmount, stereoWidth: params.stereoWidth)
        }

        // 6. Space/reverb
        if params.reverbAmount > 0 {
            output = applyReverb(output, amount: params.reverbAmount, size: params.reverbSize)
        }

        // 7. Humanization (micro timing, pitch variations)
        output = humanizer.apply(output)

        return output
    }

    // MARK: - Formant Processing

    private func applyFormants(_ samples: [Float], shift: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)

        // Blend multiple formant resonances
        for filter in formantFilters {
            let filtered = filter.process(samples, shift: Float(shift))
            vDSP_vadd(output, 1, filtered, 1, &output, 1, vDSP_Length(output.count))
        }

        // Normalize
        var scale: Float = 1.0 / Float(formantFilters.count)
        vDSP_vsmul(output, 1, &scale, &output, 1, vDSP_Length(output.count))

        return output
    }

    // MARK: - Vibrato

    private func applyVibrato(_ samples: [Float], depth: Double, rate: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let sampleRate = 44100.0

        for i in 0..<samples.count {
            let phase = Double(i) / sampleRate * rate * 2.0 * .pi
            let pitchMod = 1.0 + sin(phase) * depth * 0.02 // ±2% max
            let readIndex = Double(i) * pitchMod
            let intIndex = Int(readIndex)
            let frac = Float(readIndex - Double(intIndex))

            if intIndex >= 0 && intIndex < samples.count - 1 {
                output[i] = samples[intIndex] * (1 - frac) + samples[intIndex + 1] * frac
            } else if intIndex >= 0 && intIndex < samples.count {
                output[i] = samples[intIndex]
            }
        }

        return output
    }

    // MARK: - Breathiness

    private func addBreathiness(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples
        let noise = breathGenerator.generate(count: samples.count)

        // Mix noise with signal, following amplitude envelope
        for i in 0..<samples.count {
            let envelope = abs(samples[i])
            output[i] += noise[i] * Float(amount) * envelope * 0.3
        }

        return output
    }

    // MARK: - Tone Shaping

    private func applyToneShaping(_ samples: [Float], warmth: Double, brightness: Double) -> [Float] {
        var output = samples

        // Low shelf for warmth
        if warmth != 0.5 {
            let warmthGain = Float((warmth - 0.5) * 6) // ±3dB
            output = applyLowShelf(output, frequency: 300, gain: warmthGain)
        }

        // High shelf for brightness
        if brightness != 0.5 {
            let brightGain = Float((brightness - 0.5) * 8) // ±4dB
            output = applyHighShelf(output, frequency: 3000, gain: brightGain)
        }

        return output
    }

    private func applyLowShelf(_ samples: [Float], frequency: Float, gain: Float) -> [Float] {
        // Simple one-pole low shelf approximation
        var output = [Float](repeating: 0, count: samples.count)
        let alpha: Float = frequency / 44100.0
        let gainLin = pow(10, gain / 20)
        var lowpass: Float = 0

        for i in 0..<samples.count {
            lowpass = lowpass + alpha * (samples[i] - lowpass)
            let highpass = samples[i] - lowpass
            output[i] = lowpass * gainLin + highpass
        }

        return output
    }

    private func applyHighShelf(_ samples: [Float], frequency: Float, gain: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let alpha: Float = frequency / 44100.0
        let gainLin = pow(10, gain / 20)
        var lowpass: Float = 0

        for i in 0..<samples.count {
            lowpass = lowpass + alpha * (samples[i] - lowpass)
            let highpass = samples[i] - lowpass
            output[i] = lowpass + highpass * gainLin
        }

        return output
    }

    // MARK: - Choir Ensemble

    private func applyChoirEnsemble(_ samples: [Float], amount: Double, stereoWidth: Double) -> [Float] {
        return chorusEngine.process(samples, voices: Int(amount * 8) + 1, spread: stereoWidth)
    }

    // MARK: - Reverb

    private func applyReverb(_ samples: [Float], amount: Double, size: Double) -> [Float] {
        return reverbEngine.process(samples, wetDry: amount, roomSize: size)
    }
}

// MARK: - Formant Filter

public class FormantFilter {
    private var frequency: Float
    private var bandwidth: Float
    private var gain: Float

    // Filter state
    private var z1: Float = 0
    private var z2: Float = 0

    public init(frequency: Float, bandwidth: Float, gain: Float) {
        self.frequency = frequency
        self.bandwidth = bandwidth
        self.gain = gain
    }

    public func process(_ samples: [Float], shift: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let shiftedFreq = frequency * shift
        let sampleRate: Float = 44100

        // Bandpass coefficients (simplified)
        let omega = 2.0 * Float.pi * shiftedFreq / sampleRate
        let alpha = sin(omega) * sinh(log(2) / 2.0 * bandwidth * omega / sin(omega))
        let b0 = alpha
        let b1: Float = 0
        let b2 = -alpha
        let a0 = 1 + alpha
        let a1 = -2 * cos(omega)
        let a2 = 1 - alpha

        for i in 0..<samples.count {
            let input = samples[i]
            let filtered = (b0/a0) * input + (b1/a0) * z1 + (b2/a0) * z2
                          - (a1/a0) * z1 - (a2/a0) * z2
            z2 = z1
            z1 = input
            output[i] = filtered * gain
        }

        return output
    }

    public static func createVowelSet() -> [FormantFilter] {
        // Average formant frequencies for mixed vowels
        return [
            FormantFilter(frequency: 500, bandwidth: 1.5, gain: 1.0),   // F1
            FormantFilter(frequency: 1500, bandwidth: 1.2, gain: 0.8),  // F2
            FormantFilter(frequency: 2500, bandwidth: 1.0, gain: 0.5),  // F3
            FormantFilter(frequency: 3500, bandwidth: 0.8, gain: 0.3),  // F4
        ]
    }
}

// MARK: - Choir Chorus Engine

public class ChoirChorusEngine {
    private var delayLines: [[Float]] = []
    private var delayPositions: [Int] = []
    private var lfoPhases: [Float] = []

    public init() {
        // Pre-allocate for up to 16 voices
        for _ in 0..<16 {
            delayLines.append([Float](repeating: 0, count: 4410)) // 100ms max
            delayPositions.append(0)
            lfoPhases.append(Float.random(in: 0..<(2 * .pi)))
        }
    }

    public func process(_ samples: [Float], voices: Int, spread: Double) -> [Float] {
        guard voices > 1 else { return samples }

        var output = samples
        let voiceCount = min(voices, 16)

        for v in 1..<voiceCount {
            // Each voice has slight pitch/time variation
            let detuneAmount = (Float(v) - Float(voiceCount) / 2) * 0.003 * Float(spread)
            let delayMs = 5.0 + Float(v) * 3.0 // 5-50ms spread

            var voiceOutput = processVoice(
                samples,
                voiceIndex: v,
                detune: detuneAmount,
                delayMs: delayMs
            )

            // Pan voices across stereo field
            let pan = (Float(v) / Float(voiceCount) - 0.5) * 2 * Float(spread)
            _ = pan // Would be used for stereo output

            // Mix with slight reduction per voice
            let voiceGain = 1.0 / sqrt(Float(voiceCount))
            vDSP_vsma(voiceOutput, 1, [voiceGain], output, 1, &output, 1, vDSP_Length(output.count))
        }

        // Normalize
        var normalizeGain = 1.0 / sqrt(Float(voiceCount))
        vDSP_vsmul(output, 1, &normalizeGain, &output, 1, vDSP_Length(output.count))

        return output
    }

    private func processVoice(_ samples: [Float], voiceIndex: Int, detune: Float, delayMs: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let delaySamples = Int(delayMs * 44.1)
        let lfoRate: Float = 0.3 + Float(voiceIndex) * 0.1

        for i in 0..<samples.count {
            // LFO modulation
            lfoPhases[voiceIndex] += lfoRate * 2 * .pi / 44100
            if lfoPhases[voiceIndex] > 2 * .pi { lfoPhases[voiceIndex] -= 2 * .pi }
            let lfoMod = sin(lfoPhases[voiceIndex]) * 0.002

            // Write to delay line
            let writePos = (delayPositions[voiceIndex] + delaySamples) % delayLines[voiceIndex].count
            delayLines[voiceIndex][delayPositions[voiceIndex]] = samples[i]

            // Read with pitch shift
            let readOffset = Float(delaySamples) * (1 + detune + lfoMod)
            let readPos = (delayPositions[voiceIndex] - Int(readOffset) + delayLines[voiceIndex].count) % delayLines[voiceIndex].count

            output[i] = delayLines[voiceIndex][readPos]

            delayPositions[voiceIndex] = (delayPositions[voiceIndex] + 1) % delayLines[voiceIndex].count
        }

        return output
    }
}

// MARK: - Choir Reverb Engine

public class ChoirReverbEngine {
    // Schroeder reverb with early reflections
    private var earlyDelays: [Int] = [441, 882, 1323, 2205]  // Early reflections
    private var earlyGains: [Float] = [0.8, 0.6, 0.4, 0.3]
    private var combDelays: [Int] = [1557, 1617, 1491, 1422, 1277, 1356]
    private var combBuffers: [[Float]] = []
    private var combPositions: [Int] = []
    private var allpassDelays: [Int] = [225, 556, 441, 341]
    private var allpassBuffers: [[Float]] = []
    private var allpassPositions: [Int] = []

    public init() {
        // Initialize comb filters
        for delay in combDelays {
            combBuffers.append([Float](repeating: 0, count: delay))
            combPositions.append(0)
        }

        // Initialize allpass filters
        for delay in allpassDelays {
            allpassBuffers.append([Float](repeating: 0, count: delay))
            allpassPositions.append(0)
        }
    }

    public func process(_ samples: [Float], wetDry: Double, roomSize: Double) -> [Float] {
        var wet = [Float](repeating: 0, count: samples.count)

        // Early reflections
        for i in 0..<earlyDelays.count {
            let delay = earlyDelays[i]
            let gain = earlyGains[i]
            for j in delay..<samples.count {
                wet[j] += samples[j - delay] * gain * 0.25
            }
        }

        // Parallel comb filters
        let feedback = Float(0.7 + roomSize * 0.25)
        for c in 0..<combDelays.count {
            for i in 0..<samples.count {
                let delayed = combBuffers[c][combPositions[c]]
                let input = samples[i] + delayed * feedback
                combBuffers[c][combPositions[c]] = input
                combPositions[c] = (combPositions[c] + 1) % combDelays[c]
                wet[i] += delayed / Float(combDelays.count)
            }
        }

        // Series allpass filters for diffusion
        var diffused = wet
        let allpassGain: Float = 0.5
        for a in 0..<allpassDelays.count {
            for i in 0..<diffused.count {
                let delayed = allpassBuffers[a][allpassPositions[a]]
                let input = diffused[i] + delayed * allpassGain
                allpassBuffers[a][allpassPositions[a]] = input
                allpassPositions[a] = (allpassPositions[a] + 1) % allpassDelays[a]
                diffused[i] = delayed - input * allpassGain
            }
        }

        // Mix wet/dry
        var output = [Float](repeating: 0, count: samples.count)
        let wetGain = Float(wetDry)
        let dryGain = Float(1 - wetDry)
        for i in 0..<samples.count {
            output[i] = samples[i] * dryGain + diffused[i] * wetGain
        }

        return output
    }
}

// MARK: - Breath Noise Generator

public class BreathNoiseGenerator {
    private var noiseBuffer: [Float] = []
    private var position = 0

    public init() {
        // Pre-generate filtered noise
        noiseBuffer = [Float](repeating: 0, count: 44100)
        for i in 0..<noiseBuffer.count {
            noiseBuffer[i] = Float.random(in: -1...1)
        }

        // Lowpass filter the noise
        var filtered: Float = 0
        let alpha: Float = 0.1
        for i in 0..<noiseBuffer.count {
            filtered = filtered + alpha * (noiseBuffer[i] - filtered)
            noiseBuffer[i] = filtered
        }
    }

    public func generate(count: Int) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        for i in 0..<count {
            output[i] = noiseBuffer[position]
            position = (position + 1) % noiseBuffer.count
        }
        return output
    }
}

// MARK: - Vibrato LFO

public class VibratoLFO {
    private var phase: Double = 0

    public func generate(count: Int, rate: Double, depth: Double) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        let increment = rate * 2 * .pi / 44100

        for i in 0..<count {
            output[i] = Float(sin(phase) * depth)
            phase += increment
            if phase > 2 * .pi { phase -= 2 * .pi }
        }

        return output
    }
}

// MARK: - Voice Ensemble

public class VoiceEnsemble {
    public struct Voice {
        var pitch: Float = 1.0
        var timing: Float = 0
        var amplitude: Float = 1.0
        var formantShift: Float = 1.0
    }

    private var voices: [Voice] = []

    public init(count: Int = 8) {
        for i in 0..<count {
            var voice = Voice()
            // Slight variations for each voice
            voice.pitch = 1.0 + Float.random(in: -0.01...0.01)
            voice.timing = Float.random(in: -0.01...0.01) // ±10ms
            voice.amplitude = 0.9 + Float.random(in: 0...0.2)
            voice.formantShift = 1.0 + Float.random(in: -0.05...0.05)
            voices.append(voice)
        }
    }

    public func getVoices() -> [Voice] {
        return voices
    }
}

// MARK: - Voice Humanizer

public class VoiceHumanizer {
    private var pitchDrift: Float = 0
    private var timingJitter: Float = 0

    public func apply(_ samples: [Float]) -> [Float] {
        var output = samples

        // Subtle pitch drift (very slow LFO)
        let driftRate: Float = 0.1 // Hz
        for i in 0..<output.count {
            let driftPhase = Float(i) / 44100 * driftRate * 2 * .pi
            let drift = sin(driftPhase) * 0.001 // ±0.1% pitch
            // Apply drift (simplified - just amplitude modulation as proxy)
            output[i] *= 1 + drift
        }

        // Micro timing variations (very subtle)
        // In real implementation, this would shift samples

        return output
    }
}

// MARK: - Original Voice Processor

public final class OriginalVoiceProcessor {

    public init() {}

    public func process(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Minimal processing for "original" character
        // Just apply subtle warmth and air if requested

        if params.warmth > 0.5 {
            output = addWarmth(output, amount: (params.warmth - 0.5) * 2)
        }

        if params.brightness > 0.5 {
            output = addBrightness(output, amount: (params.brightness - 0.5) * 2)
        }

        if params.harmonicRichness > 0.5 {
            output = enhanceHarmonics(output, amount: (params.harmonicRichness - 0.5) * 2)
        }

        return output
    }

    private func addWarmth(_ samples: [Float], amount: Double) -> [Float] {
        // Gentle saturation
        return samples.map { sample in
            let x = sample * Float(1 + amount * 0.3)
            return tanh(x) * Float(1 / (1 + amount * 0.1))
        }
    }

    private func addBrightness(_ samples: [Float], amount: Double) -> [Float] {
        // High frequency emphasis
        var output = [Float](repeating: 0, count: samples.count)
        var prev: Float = 0

        for i in 0..<samples.count {
            let highpass = samples[i] - prev
            prev = samples[i]
            output[i] = samples[i] + highpass * Float(amount * 0.3)
        }

        return output
    }

    private func enhanceHarmonics(_ samples: [Float], amount: Double) -> [Float] {
        // Subtle harmonic generation via soft clipping
        return samples.map { sample in
            let enhanced = sample + (sample * sample * sample) * Float(amount * 0.1)
            return enhanced / (1 + abs(enhanced) * 0.1)
        }
    }
}
