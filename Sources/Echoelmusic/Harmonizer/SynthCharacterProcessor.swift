import Foundation
import Accelerate

// MARK: - Synth Character Processor
// Comprehensive synthesizer voice emulation
// Supports: Analog, Digital, Wavetable, FM, Granular, Vocoder, etc.

public final class SynthCharacterProcessor {

    // Synth components
    private var oscillators: [SynthOscillator] = []
    private var filters: [SynthFilter] = []
    private var envelopes: [ADSREnvelope] = []
    private var lfos: [SynthLFO] = []

    // Specialized processors
    private var wavetableEngine: WavetableEngine
    private var fmEngine: FMSynthEngine
    private var granularEngine: GranularEngine
    private var vocoderEngine: VocoderEngine
    private var supersawEngine: SupersawEngine

    // Effects
    private var chorusEffect: SynthChorusEffect
    private var phaserEffect: PhaserEffect
    private var distortion: SynthDistortion

    public init() {
        // Initialize 8 oscillators for unison
        for _ in 0..<8 {
            oscillators.append(SynthOscillator())
            filters.append(SynthFilter())
            envelopes.append(ADSREnvelope())
            lfos.append(SynthLFO())
        }

        self.wavetableEngine = WavetableEngine()
        self.fmEngine = FMSynthEngine()
        self.granularEngine = GranularEngine()
        self.vocoderEngine = VocoderEngine()
        self.supersawEngine = SupersawEngine()
        self.chorusEffect = SynthChorusEffect()
        self.phaserEffect = PhaserEffect()
        self.distortion = SynthDistortion()
    }

    // MARK: - Main Processing

    public func process(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Determine synth type from parameters
        if params.fmDepth > 0 {
            output = processFM(output, params: params)
        } else if params.grainDensity > 0 && params.grainDensity != 0.5 {
            output = processGranular(output, params: params)
        } else if params.vocoderBands > 8 {
            output = processVocoder(output, params: params)
        } else if params.unisonVoices > 1 {
            output = processSupersaw(output, params: params)
        } else if params.wavetablePosition > 0 || params.morphRate > 0 {
            output = processWavetable(output, params: params)
        } else {
            output = processAnalog(output, params: params)
        }

        // Apply common synth effects
        output = applyFilter(output, cutoff: params.filterCutoff, resonance: params.filterResonance)

        if params.chorusAmount > 0 {
            output = chorusEffect.process(output, depth: params.chorusAmount, rate: 1.5)
        }

        if params.detuneAmount > 0 && params.unisonVoices <= 1 {
            output = applyDetune(output, amount: params.detuneAmount)
        }

        // Warmth (analog saturation)
        if params.warmth > 0.5 {
            output = distortion.process(output, drive: (params.warmth - 0.5) * 0.5, type: .tube)
        }

        // Sub harmonics
        if params.subHarmonics > 0 {
            output = addSubOctave(output, amount: params.subHarmonics)
        }

        return output
    }

    // MARK: - Analog Processing

    private func processAnalog(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Analog warmth - subtle saturation
        if params.warmth > 0 {
            output = analogSaturation(output, drive: Float(params.warmth))
        }

        // Analog drift (subtle pitch/level variations)
        output = addAnalogDrift(output, amount: 0.002)

        // Vintage filter character
        output = applyVintageFilter(output, cutoff: params.filterCutoff)

        return output
    }

    private func analogSaturation(_ samples: [Float], drive: Float) -> [Float] {
        return samples.map { sample in
            let x = sample * (1 + drive * 2)
            // Soft clipping with asymmetry for analog character
            let positive = tanh(x * 0.8)
            let negative = tanh(x * 1.2)
            return x >= 0 ? positive : negative * 0.9
        }
    }

    private func addAnalogDrift(_ samples: [Float], amount: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        var drift: Float = 0
        let driftRate: Float = 0.00001

        for i in 0..<samples.count {
            // Random walk drift
            drift += Float.random(in: -driftRate...driftRate)
            drift = max(-amount, min(amount, drift))
            output[i] = samples[i] * (1 + drift)
        }

        return output
    }

    private func applyVintageFilter(_ samples: [Float], cutoff: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        var lp1: Float = 0, lp2: Float = 0
        let freq = Float(cutoff * cutoff * 15000 + 100) // Exponential mapping
        let g = tan(.pi * freq / 44100)
        let k: Float = 1.0 // Resonance

        for i in 0..<samples.count {
            let input = samples[i]
            let hp = (input - (k + g) * lp1 - lp2) / (1 + g * (k + g))
            let bp = g * hp + lp1
            lp1 = g * hp + bp
            let lp = g * bp + lp2
            lp2 = g * bp + lp

            output[i] = lp
        }

        return output
    }

    // MARK: - FM Processing

    private func processFM(_ samples: [Float], params: CharacterParameters) -> [Float] {
        return fmEngine.process(samples, ratio: params.fmRatio, depth: params.fmDepth)
    }

    // MARK: - Wavetable Processing

    private func processWavetable(_ samples: [Float], params: CharacterParameters) -> [Float] {
        return wavetableEngine.process(
            samples,
            position: params.wavetablePosition,
            morphRate: params.morphRate
        )
    }

    // MARK: - Granular Processing

    private func processGranular(_ samples: [Float], params: CharacterParameters) -> [Float] {
        return granularEngine.process(
            samples,
            grainSize: params.grainSize,
            density: params.grainDensity,
            pitch: params.grainPitch
        )
    }

    // MARK: - Vocoder Processing

    private func processVocoder(_ samples: [Float], params: CharacterParameters) -> [Float] {
        return vocoderEngine.process(
            samples,
            bands: params.vocoderBands,
            attack: params.vocoderAttack,
            release: params.vocoderRelease
        )
    }

    // MARK: - Supersaw Processing

    private func processSupersaw(_ samples: [Float], params: CharacterParameters) -> [Float] {
        return supersawEngine.process(
            samples,
            voices: params.unisonVoices,
            detune: params.detuneAmount,
            spread: params.stereoWidth
        )
    }

    // MARK: - Common Effects

    private func applyFilter(_ samples: [Float], cutoff: Double, resonance: Double) -> [Float] {
        guard cutoff < 1.0 else { return samples }

        var output = [Float](repeating: 0, count: samples.count)
        var lp: Float = 0
        var bp: Float = 0

        let freq = Float(cutoff * cutoff * 20000 + 20)
        let g = tan(.pi * freq / 44100)
        let k = Float(2.0 - 2.0 * resonance * 0.99) // Prevent self-oscillation

        for i in 0..<samples.count {
            let hp = (samples[i] - (k + g) * bp - lp) / (1 + k * g + g * g)
            bp = g * hp + bp
            lp = g * bp + lp
            output[i] = lp
        }

        return output
    }

    private func applyDetune(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples
        let detuneUp = pitchShift(samples, semitones: Float(amount * 0.1))
        let detuneDown = pitchShift(samples, semitones: Float(-amount * 0.1))

        for i in 0..<samples.count {
            output[i] = (samples[i] + detuneUp[i] + detuneDown[i]) / 3
        }

        return output
    }

    private func pitchShift(_ samples: [Float], semitones: Float) -> [Float] {
        let ratio = pow(2, semitones / 12)
        var output = [Float](repeating: 0, count: samples.count)

        for i in 0..<samples.count {
            let readPos = Float(i) * ratio
            let index = Int(readPos)
            let frac = readPos - Float(index)

            if index >= 0 && index < samples.count - 1 {
                output[i] = samples[index] * (1 - frac) + samples[index + 1] * frac
            }
        }

        return output
    }

    private func addSubOctave(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples
        var subPhase: Float = 0
        var envelope: Float = 0

        for i in 0..<samples.count {
            // Track zero crossings for sub oscillator
            if i > 0 && samples[i] > 0 && samples[i-1] <= 0 {
                subPhase = 0
            }
            subPhase += 0.5 // Half frequency

            // Simple square sub
            let sub = subPhase.truncatingRemainder(dividingBy: 2) < 1 ? Float(1) : Float(-1)

            // Envelope follower
            let target = abs(samples[i])
            envelope = envelope * 0.99 + target * 0.01

            output[i] += sub * Float(amount) * envelope * 0.3
        }

        return output
    }
}

// MARK: - Synth Oscillator

public class SynthOscillator {
    public enum Waveform {
        case sine, saw, square, triangle, noise
    }

    private var phase: Float = 0
    private var waveform: Waveform = .saw

    public func generate(count: Int, frequency: Float, waveform: Waveform) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        let phaseIncrement = frequency / 44100

        for i in 0..<count {
            switch waveform {
            case .sine:
                output[i] = sin(phase * 2 * .pi)
            case .saw:
                output[i] = 2 * phase - 1
            case .square:
                output[i] = phase < 0.5 ? 1 : -1
            case .triangle:
                output[i] = 4 * abs(phase - 0.5) - 1
            case .noise:
                output[i] = Float.random(in: -1...1)
            }

            phase += phaseIncrement
            if phase >= 1 { phase -= 1 }
        }

        return output
    }
}

// MARK: - Synth Filter

public class SynthFilter {
    public enum FilterType {
        case lowpass, highpass, bandpass, notch
    }

    private var lp: Float = 0
    private var bp: Float = 0

    public func process(_ samples: [Float], cutoff: Float, resonance: Float, type: FilterType) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let g = tan(.pi * cutoff / 44100)
        let k = 2.0 - 2.0 * resonance * 0.99

        for i in 0..<samples.count {
            let hp = (samples[i] - (k + g) * bp - lp) / (1 + k * g + g * g)
            bp = g * hp + bp
            lp = g * bp + lp

            switch type {
            case .lowpass: output[i] = lp
            case .highpass: output[i] = hp
            case .bandpass: output[i] = bp
            case .notch: output[i] = hp + lp
            }
        }

        return output
    }
}

// MARK: - ADSR Envelope

public class ADSREnvelope {
    private var stage: Int = 0
    private var value: Float = 0
    private var attackRate: Float = 0.01
    private var decayRate: Float = 0.001
    private var sustainLevel: Float = 0.7
    private var releaseRate: Float = 0.0005

    public func generate(count: Int, gate: Bool) -> [Float] {
        var output = [Float](repeating: 0, count: count)

        for i in 0..<count {
            if gate {
                switch stage {
                case 0: // Attack
                    value += attackRate
                    if value >= 1 { value = 1; stage = 1 }
                case 1: // Decay
                    value -= decayRate
                    if value <= sustainLevel { value = sustainLevel; stage = 2 }
                default: // Sustain
                    break
                }
            } else {
                // Release
                value -= releaseRate
                if value < 0 { value = 0 }
                stage = 0
            }

            output[i] = value
        }

        return output
    }

    public func configure(attack: Float, decay: Float, sustain: Float, release: Float) {
        attackRate = 1.0 / max(attack * 44100, 1)
        decayRate = (1 - sustain) / max(decay * 44100, 1)
        sustainLevel = sustain
        releaseRate = sustain / max(release * 44100, 1)
    }
}

// MARK: - Synth LFO

public class SynthLFO {
    private var phase: Float = 0

    public func generate(count: Int, rate: Float, waveform: SynthOscillator.Waveform = .sine) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        let phaseIncrement = rate / 44100

        for i in 0..<count {
            switch waveform {
            case .sine:
                output[i] = sin(phase * 2 * .pi)
            case .saw:
                output[i] = 2 * phase - 1
            case .square:
                output[i] = phase < 0.5 ? 1 : -1
            case .triangle:
                output[i] = 4 * abs(phase - 0.5) - 1
            case .noise:
                output[i] = Float.random(in: -1...1)
            }

            phase += phaseIncrement
            if phase >= 1 { phase -= 1 }
        }

        return output
    }
}

// MARK: - Wavetable Engine

public class WavetableEngine {
    private var wavetables: [[Float]] = []
    private var phase: Float = 0

    public init() {
        // Generate basic wavetables
        wavetables = [
            generateWavetable(.sine),
            generateWavetable(.saw),
            generateWavetable(.square),
            generateWavetable(.triangle),
            generatePWM(0.25),
            generatePWM(0.1),
            generateFormantWave(500),
            generateFormantWave(1000),
        ]
    }

    private func generateWavetable(_ waveform: SynthOscillator.Waveform) -> [Float] {
        var table = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            let phase = Float(i) / 2048
            switch waveform {
            case .sine: table[i] = sin(phase * 2 * .pi)
            case .saw: table[i] = 2 * phase - 1
            case .square: table[i] = phase < 0.5 ? 1 : -1
            case .triangle: table[i] = 4 * abs(phase - 0.5) - 1
            case .noise: table[i] = Float.random(in: -1...1)
            }
        }
        return table
    }

    private func generatePWM(_ width: Float) -> [Float] {
        var table = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            let phase = Float(i) / 2048
            table[i] = phase < width ? 1 : -1
        }
        return table
    }

    private func generateFormantWave(_ freq: Float) -> [Float] {
        var table = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            let phase = Float(i) / 2048
            let carrier = sin(phase * 2 * .pi)
            let formant = sin(phase * 2 * .pi * (freq / 100))
            table[i] = carrier * (0.7 + 0.3 * formant)
        }
        return table
    }

    public func process(_ samples: [Float], position: Double, morphRate: Double) -> [Float] {
        guard !wavetables.isEmpty else { return samples }

        var output = [Float](repeating: 0, count: samples.count)
        var morphPosition = Float(position) * Float(wavetables.count - 1)

        for i in 0..<samples.count {
            // Morph between wavetables
            if morphRate > 0 {
                morphPosition += Float(morphRate * 0.0001)
                if morphPosition >= Float(wavetables.count - 1) {
                    morphPosition = 0
                }
            }

            let tableIndex = Int(morphPosition)
            let tableFrac = morphPosition - Float(tableIndex)

            let nextIndex = min(tableIndex + 1, wavetables.count - 1)

            // Read from wavetables
            let phaseIndex = Int(phase * 2048) % 2048
            let sample1 = wavetables[tableIndex][phaseIndex]
            let sample2 = wavetables[nextIndex][phaseIndex]

            // Crossfade
            let wavetableSample = sample1 * (1 - tableFrac) + sample2 * tableFrac

            // Modulate with input
            output[i] = samples[i] * 0.3 + wavetableSample * 0.7

            // Advance phase based on input frequency estimation
            phase += 0.01 // Fixed for now
            if phase >= 1 { phase -= 1 }
        }

        return output
    }
}

// MARK: - FM Synth Engine

public class FMSynthEngine {
    private var carrierPhase: Float = 0
    private var modulatorPhase: Float = 0

    public func process(_ samples: [Float], ratio: Double, depth: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let modRatio = Float(ratio)
        let modDepth = Float(depth)

        // Estimate fundamental from input
        let baseFreq: Float = 440 // Would be detected in real implementation

        for i in 0..<samples.count {
            // Modulator
            let modFreq = baseFreq * modRatio
            modulatorPhase += modFreq / 44100
            if modulatorPhase >= 1 { modulatorPhase -= 1 }
            let modulator = sin(modulatorPhase * 2 * .pi) * modDepth

            // Carrier with FM
            carrierPhase += (baseFreq + modulator * baseFreq) / 44100
            if carrierPhase >= 1 { carrierPhase -= 1 }
            let carrier = sin(carrierPhase * 2 * .pi)

            // Mix with input
            output[i] = samples[i] * 0.3 + carrier * abs(samples[i]) * 0.7
        }

        return output
    }
}

// MARK: - Granular Engine

public class GranularEngine {
    private var grainBuffer: [Float] = []
    private var grainPositions: [Int] = []
    private var grainPhases: [Float] = []
    private var nextGrainTime: Int = 0

    public init() {
        grainBuffer = [Float](repeating: 0, count: 44100) // 1 second buffer
        grainPositions = [Int](repeating: 0, count: 32)
        grainPhases = [Float](repeating: -1, count: 32) // -1 = inactive
    }

    public func process(_ samples: [Float], grainSize: Double, density: Double, pitch: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let grainSamples = Int(grainSize * 44100)
        let grainInterval = Int((1.0 - density) * 1000) + 10

        // Fill grain buffer
        for i in 0..<min(samples.count, grainBuffer.count) {
            grainBuffer[i] = samples[i]
        }

        for i in 0..<samples.count {
            // Spawn new grains
            if i >= nextGrainTime {
                if let inactiveIndex = grainPhases.firstIndex(of: -1) {
                    grainPhases[inactiveIndex] = 0
                    grainPositions[inactiveIndex] = Int.random(in: 0..<grainBuffer.count)
                }
                nextGrainTime = i + grainInterval
            }

            // Process active grains
            for g in 0..<grainPhases.count {
                if grainPhases[g] >= 0 {
                    let grainProgress = grainPhases[g]
                    let window = hannWindow(grainProgress)

                    let readPos = (grainPositions[g] + Int(grainProgress * Float(grainSamples) * Float(pitch))) % grainBuffer.count
                    output[i] += grainBuffer[readPos] * window * 0.3

                    grainPhases[g] += 1.0 / Float(grainSamples)
                    if grainPhases[g] >= 1 {
                        grainPhases[g] = -1 // Deactivate
                    }
                }
            }
        }

        return output
    }

    private func hannWindow(_ phase: Float) -> Float {
        return 0.5 * (1 - cos(2 * .pi * phase))
    }
}

// MARK: - Vocoder Engine

public class VocoderEngine {
    private var analysisBands: [BandpassFilter] = []
    private var synthesisBands: [BandpassFilter] = []
    private var envelopes: [Float] = []

    public init() {
        // Create analysis and synthesis filter banks
        let frequencies: [Float] = [100, 200, 400, 600, 800, 1000, 1500, 2000, 3000, 4000, 5000, 6000, 8000, 10000, 12000, 16000]
        for freq in frequencies {
            analysisBands.append(BandpassFilter(frequency: freq, q: 5))
            synthesisBands.append(BandpassFilter(frequency: freq, q: 5))
        }
        envelopes = [Float](repeating: 0, count: frequencies.count)
    }

    public func process(_ samples: [Float], bands: Int, attack: Double, release: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let bandCount = min(bands, analysisBands.count)
        let attackCoef = Float(exp(-1.0 / (attack * 44100)))
        let releaseCoef = Float(exp(-1.0 / (release * 44100)))

        for i in 0..<samples.count {
            var sum: Float = 0

            for b in 0..<bandCount {
                // Analysis: extract envelope from input
                let analyzed = analysisBands[b].process(samples[i])
                let rectified = abs(analyzed)

                // Envelope follower
                if rectified > envelopes[b] {
                    envelopes[b] = attackCoef * envelopes[b] + (1 - attackCoef) * rectified
                } else {
                    envelopes[b] = releaseCoef * envelopes[b]
                }

                // Synthesis: generate carrier and modulate
                let carrier = sin(Float(i) * Float(b + 1) * 0.01) // Simple carrier
                let modulated = carrier * envelopes[b]

                sum += modulated
            }

            output[i] = sum / Float(bandCount) * 2
        }

        return output
    }
}

// MARK: - Bandpass Filter

public class BandpassFilter {
    private var z1: Float = 0
    private var z2: Float = 0
    private let frequency: Float
    private let q: Float

    public init(frequency: Float, q: Float) {
        self.frequency = frequency
        self.q = q
    }

    public func process(_ input: Float) -> Float {
        let omega = 2 * Float.pi * frequency / 44100
        let alpha = sin(omega) / (2 * q)
        let b0 = alpha
        let a0 = 1 + alpha
        let a1 = -2 * cos(omega)
        let a2 = 1 - alpha

        let output = (b0/a0) * input - (a1/a0) * z1 - (a2/a0) * z2
        z2 = z1
        z1 = output

        return output
    }
}

// MARK: - Supersaw Engine

public class SupersawEngine {
    private var phases: [Float] = []
    private var detuneAmounts: [Float] = []

    public init() {
        phases = [Float](repeating: 0, count: 9)
        detuneAmounts = [-0.11, -0.06, -0.03, -0.01, 0, 0.01, 0.03, 0.06, 0.11]
    }

    public func process(_ samples: [Float], voices: Int, detune: Double, spread: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let voiceCount = min(voices, 9)
        let detuneScale = Float(detune)

        // Estimate frequency from input (simplified)
        let baseFreq: Float = 440

        for i in 0..<samples.count {
            var sum: Float = 0

            for v in 0..<voiceCount {
                let voiceDetune = detuneAmounts[v] * detuneScale
                let voiceFreq = baseFreq * (1 + voiceDetune)

                phases[v] += voiceFreq / 44100
                if phases[v] >= 1 { phases[v] -= 1 }

                // Band-limited saw approximation
                let saw = 2 * phases[v] - 1
                sum += saw
            }

            // Normalize and mix with input
            let sawMix = sum / Float(voiceCount)
            output[i] = samples[i] * 0.2 + sawMix * abs(samples[i]) * 0.8
        }

        return output
    }
}

// MARK: - Synth Chorus Effect

public class SynthChorusEffect {
    private var delayLine: [Float] = []
    private var writePos: Int = 0
    private var lfoPhase: Float = 0

    public init() {
        delayLine = [Float](repeating: 0, count: 4410) // 100ms max
    }

    public func process(_ samples: [Float], depth: Double, rate: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let baseDelay: Float = 1000 // ~22ms
        let modDepth = Float(depth) * 500

        for i in 0..<samples.count {
            // Write to delay line
            delayLine[writePos] = samples[i]

            // LFO modulation
            lfoPhase += Float(rate) / 44100
            if lfoPhase >= 1 { lfoPhase -= 1 }
            let lfo = sin(lfoPhase * 2 * .pi)

            // Read with modulated delay
            let delay = baseDelay + lfo * modDepth
            let readPos = (writePos - Int(delay) + delayLine.count) % delayLine.count

            // Mix
            output[i] = samples[i] * 0.7 + delayLine[readPos] * 0.3

            writePos = (writePos + 1) % delayLine.count
        }

        return output
    }
}

// MARK: - Phaser Effect

public class PhaserEffect {
    private var allpassFilters: [AllpassFilter] = []
    private var lfoPhase: Float = 0

    public init() {
        for _ in 0..<6 {
            allpassFilters.append(AllpassFilter())
        }
    }

    public func process(_ samples: [Float], depth: Double, rate: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)

        for i in 0..<samples.count {
            // LFO
            lfoPhase += Float(rate) / 44100
            if lfoPhase >= 1 { lfoPhase -= 1 }
            let lfo = (sin(lfoPhase * 2 * .pi) + 1) * 0.5

            // Sweep frequency
            let freq = 200 + lfo * Float(depth) * 3000

            var filtered = samples[i]
            for ap in allpassFilters {
                filtered = ap.process(filtered, frequency: freq)
            }

            output[i] = samples[i] * 0.5 + filtered * 0.5
        }

        return output
    }
}

// MARK: - Allpass Filter

public class AllpassFilter {
    private var z: Float = 0

    public func process(_ input: Float, frequency: Float) -> Float {
        let a = (1 - frequency / 44100) / (1 + frequency / 44100)
        let output = a * input + z - a * z
        z = input
        return output
    }
}

// MARK: - Synth Distortion

public class SynthDistortion {
    public enum DistortionType {
        case tube, transistor, foldback, bitcrush
    }

    public func process(_ samples: [Float], drive: Double, type: DistortionType) -> [Float] {
        switch type {
        case .tube:
            return tubeSaturation(samples, drive: Float(drive))
        case .transistor:
            return transistorClip(samples, drive: Float(drive))
        case .foldback:
            return foldbackDistortion(samples, threshold: Float(1 - drive * 0.5))
        case .bitcrush:
            return bitcrush(samples, bits: Int((1 - drive) * 14) + 2)
        }
    }

    private func tubeSaturation(_ samples: [Float], drive: Float) -> [Float] {
        return samples.map { sample in
            let x = sample * (1 + drive * 3)
            // Asymmetric soft clipping
            if x >= 0 {
                return tanh(x * 0.9)
            } else {
                return tanh(x * 1.1) * 0.95
            }
        }
    }

    private func transistorClip(_ samples: [Float], drive: Float) -> [Float] {
        return samples.map { sample in
            let x = sample * (1 + drive * 5)
            return max(-1, min(1, x)) // Hard clip
        }
    }

    private func foldbackDistortion(_ samples: [Float], threshold: Float) -> [Float] {
        return samples.map { sample in
            var x = sample
            while abs(x) > threshold {
                if x > threshold {
                    x = 2 * threshold - x
                } else if x < -threshold {
                    x = -2 * threshold - x
                }
            }
            return x
        }
    }

    private func bitcrush(_ samples: [Float], bits: Int) -> [Float] {
        let levels = Float(1 << bits)
        return samples.map { sample in
            return floor(sample * levels) / levels
        }
    }
}
