import Foundation
import Accelerate

// MARK: - Acoustic Instrument Processor
// Physical modeling and sample-based synthesis for acoustic instruments
// Supports: Strings, Brass, Woodwinds, Keyboards, Plucked, Ethnic

public final class AcousticInstrumentProcessor {

    // Physical modeling engines
    private var stringModel: StringPhysicalModel
    private var brassModel: BrassPhysicalModel
    private var woodwindModel: WoodwindPhysicalModel
    private var percussionModel: PercussionModel

    // Body resonance simulation
    private var bodyResonator: InstrumentBodyResonator

    // Bow/breath/pluck excitation
    private var excitationGenerator: ExcitationGenerator

    // Room acoustics
    private var roomSimulator: AcousticRoomSimulator

    public init() {
        self.stringModel = StringPhysicalModel()
        self.brassModel = BrassPhysicalModel()
        self.woodwindModel = WoodwindPhysicalModel()
        self.percussionModel = PercussionModel()
        self.bodyResonator = InstrumentBodyResonator()
        self.excitationGenerator = ExcitationGenerator()
        self.roomSimulator = AcousticRoomSimulator()
    }

    // MARK: - Main Processing

    public func process(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Determine instrument category from parameters
        if params.bowPressure > 0 && params.bowPressure != 0.5 {
            output = processStrings(output, params: params)
        } else if params.breathiness > 0.1 && (params.reedBuzziness > 0 || params.airiness > 0.3) {
            output = processWoodwind(output, params: params)
        } else if params.breathiness > 0.1 {
            output = processBrass(output, params: params)
        } else if params.pluckPosition > 0 && params.pluckPosition != 0.5 {
            output = processPlucked(output, params: params)
        } else if params.hammerHardness > 0 && params.hammerHardness != 0.5 {
            output = processKeyboard(output, params: params)
        } else if params.bellTone > 0 {
            output = processPercussion(output, params: params)
        } else {
            output = processGenericAcoustic(output, params: params)
        }

        // Apply body resonance
        if params.bodyResonance > 0 {
            output = bodyResonator.process(output, resonance: params.bodyResonance)
        }

        // Vibrato
        if params.vibrato > 0 {
            output = applyVibrato(output, depth: params.vibrato, rate: params.vibratoRate)
        }

        // Room acoustics
        if params.reverbAmount > 0 {
            output = roomSimulator.process(output, amount: params.reverbAmount, size: params.reverbSize)
        }

        return output
    }

    // MARK: - String Processing

    private func processStrings(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Bow excitation
        let bowExcitation = excitationGenerator.generateBow(
            count: samples.count,
            pressure: params.bowPressure,
            speed: 0.5
        )

        // Modulate with bow
        for i in 0..<output.count {
            output[i] *= (1 + bowExcitation[i] * 0.3)
        }

        // String resonance
        output = stringModel.process(output, tension: 0.5, damping: 1 - params.warmth)

        // Warmth/brightness
        output = applyStringToneShaping(output, warmth: params.warmth, brightness: params.brightness)

        // Tremolo if specified
        if params.tremoloRate > 0 && params.tremoloDepth > 0 {
            output = applyTremolo(output, rate: params.tremoloRate, depth: params.tremoloDepth)
        }

        return output
    }

    private func applyStringToneShaping(_ samples: [Float], warmth: Double, brightness: Double) -> [Float] {
        var output = samples

        // Resonant low-mid boost for warmth
        if warmth > 0.5 {
            output = applyResonantBoost(output, frequency: 400, q: 2, gain: Float((warmth - 0.5) * 4))
        }

        // High frequency presence
        if brightness > 0.5 {
            output = applyHighShelf(output, frequency: 4000, gain: Float((brightness - 0.5) * 6))
        } else if brightness < 0.5 {
            output = applyHighShelf(output, frequency: 3000, gain: Float((brightness - 0.5) * 8))
        }

        return output
    }

    // MARK: - Brass Processing

    private func processBrass(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Lip buzz excitation
        let buzzExcitation = excitationGenerator.generateLipBuzz(
            count: samples.count,
            tension: 0.5,
            airPressure: params.breathiness
        )

        // Mix excitation
        for i in 0..<output.count {
            output[i] = output[i] * 0.6 + buzzExcitation[i] * abs(output[i]) * 0.4
        }

        // Brass resonance (formants)
        output = brassModel.process(output, bellSize: 0.6)

        // Brightness based on dynamics
        let dynamicBrightness = params.brightness * 1.2 // Brass gets brighter when louder
        output = applyBrassToneShaping(output, brightness: dynamicBrightness)

        // Mute if specified
        if params.filterCutoff < 0.7 {
            output = applyMute(output, depth: 1 - params.filterCutoff)
        }

        return output
    }

    private func applyBrassToneShaping(_ samples: [Float], brightness: Double) -> [Float] {
        var output = samples

        // Characteristic brass formants
        output = applyResonantBoost(output, frequency: 1200, q: 3, gain: Float(brightness * 3))
        output = applyResonantBoost(output, frequency: 2400, q: 2, gain: Float(brightness * 2))

        return output
    }

    private func applyMute(_ samples: [Float], depth: Double) -> [Float] {
        // Muted brass characteristic - nasal, filtered
        var output = samples
        var lp: Float = 0
        let cutoff = Float(2000 * (1 - depth * 0.7))
        let alpha = cutoff / 44100

        for i in 0..<output.count {
            lp = lp + alpha * (output[i] - lp)
            // Add nasal resonance
            let nasal = sin(Float(i) * 0.05) * lp * Float(depth) * 0.2
            output[i] = lp + nasal
        }

        return output
    }

    // MARK: - Woodwind Processing

    private func processWoodwind(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Breath noise
        let breathNoise = excitationGenerator.generateBreath(
            count: samples.count,
            intensity: params.breathiness
        )

        // Mix breath
        for i in 0..<output.count {
            output[i] += breathNoise[i] * Float(params.airiness) * 0.15
        }

        // Reed/embouchure buzz
        if params.reedBuzziness > 0 {
            output = addReedBuzz(output, amount: params.reedBuzziness)
        }

        // Woodwind resonances
        output = woodwindModel.process(output, boreLength: 0.5)

        // Air/breathiness
        if params.airiness > 0 {
            output = addAiriness(output, amount: params.airiness)
        }

        return output
    }

    private func addReedBuzz(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples

        for i in 0..<output.count {
            // Asymmetric distortion for reed character
            let x = output[i]
            if x > 0 {
                output[i] = x - Float(amount) * x * x * 0.3
            } else {
                output[i] = x + Float(amount) * x * x * 0.2
            }
        }

        return output
    }

    private func addAiriness(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples
        let noise = excitationGenerator.generateBreath(count: samples.count, intensity: amount)

        for i in 0..<output.count {
            let envelope = abs(samples[i])
            output[i] += noise[i] * Float(amount) * envelope * 0.2
        }

        return output
    }

    // MARK: - Plucked String Processing

    private func processPlucked(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Pluck excitation position affects harmonics
        let pluckPosition = params.pluckPosition

        // Karplus-Strong inspired processing
        output = stringModel.processPlucked(output, position: pluckPosition, damping: 1 - params.warmth)

        // Body resonance for acoustic instruments
        if params.bodyResonance > 0 {
            output = addBodyResonance(output, size: params.bodyResonance)
        }

        // Twang for banjo-like instruments
        if params.twangAmount > 0 {
            output = addTwang(output, amount: params.twangAmount)
        }

        // Sympathetic resonance for sitar
        if params.sympatheticResonance > 0 {
            output = addSympatheticResonance(output, amount: params.sympatheticResonance)
        }

        return output
    }

    private func addBodyResonance(_ samples: [Float], size: Double) -> [Float] {
        var output = samples

        // Multiple resonant modes for body
        let frequencies: [Float] = [100, 200, 400] // Body resonance frequencies
        let qValues: [Float] = [8, 5, 3]
        let gains: [Float] = [0.3, 0.2, 0.1]

        for (i, freq) in frequencies.enumerated() {
            let resonated = applyResonantBoost(output, frequency: freq * Float(0.5 + size * 0.5), q: qValues[i], gain: gains[i] * Float(size))
            for j in 0..<output.count {
                output[j] += resonated[j] * 0.3
            }
        }

        return output
    }

    private func addTwang(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples

        // High frequency emphasis on attack
        var envelope: Float = 0
        for i in 0..<output.count {
            let target = abs(samples[i])
            if target > envelope {
                envelope = target
            } else {
                envelope *= 0.9995
            }

            // Twang = high frequency boost proportional to envelope
            if i > 0 {
                let highFreq = samples[i] - samples[i-1]
                output[i] += highFreq * envelope * Float(amount) * 3
            }
        }

        return output
    }

    private func addSympatheticResonance(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples

        // Sympathetic strings tuned to harmonic series
        let sympatheticFreqs: [Float] = [130.8, 196, 261.6, 329.6, 392, 523.2] // C major-ish

        for freq in sympatheticFreqs {
            var resonator: Float = 0
            var resonatorVel: Float = 0
            let omega = 2 * Float.pi * freq / 44100
            let damping: Float = 0.999

            for i in 0..<output.count {
                // Driven harmonic oscillator
                resonatorVel += (samples[i] * 0.001 - omega * omega * resonator) / 44100
                resonatorVel *= damping
                resonator += resonatorVel

                output[i] += resonator * Float(amount) * 0.1
            }
        }

        return output
    }

    // MARK: - Keyboard Processing

    private func processKeyboard(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Hammer impact
        let hammerCharacter = percussionModel.generateHammerImpact(
            count: samples.count,
            hardness: params.hammerHardness
        )

        // Mix hammer attack
        for i in 0..<min(1000, output.count) {
            output[i] += hammerCharacter[i] * Float(params.hammerHardness) * 0.2
        }

        // String/tine resonance
        output = stringModel.process(output, tension: 0.5, damping: 0.3)

        // Bell tone for electric piano
        if params.bellTone > 0 {
            output = addBellTone(output, amount: params.bellTone)
        }

        // Sparkle for celesta
        if params.sparkle > 0 {
            output = addSparkle(output, amount: params.sparkle)
        }

        return output
    }

    private func addBellTone(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples

        // FM-like bell harmonics
        var phase: Float = 0
        var envelope: Float = 0

        for i in 0..<output.count {
            // Envelope follower
            let target = abs(samples[i])
            if target > envelope {
                envelope = target
            } else {
                envelope *= 0.9998
            }

            // Bell overtone
            phase += 0.015 // ~660Hz at 44100
            if phase >= 1 { phase -= 1 }
            let bell = sin(phase * 2 * .pi * 7) * envelope

            output[i] += bell * Float(amount) * 0.15
        }

        return output
    }

    private func addSparkle(_ samples: [Float], amount: Double) -> [Float] {
        var output = samples

        // High frequency shimmer
        var prevHigh: Float = 0
        for i in 1..<output.count {
            let high = samples[i] - samples[i-1]
            let shimmer = (high - prevHigh) * Float(amount) * 2
            prevHigh = high

            output[i] += shimmer * 0.5
        }

        return output
    }

    // MARK: - Percussion Processing

    private func processPercussion(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Bell/metallic resonance
        if params.bellTone > 0 {
            output = percussionModel.addBellResonance(output, brightness: params.brightness)
        }

        // Shimmer for gamelan
        if params.shimmer > 0 {
            output = addShimmer(output, amount: params.shimmer, detune: params.detuneAmount)
        }

        return output
    }

    private func addShimmer(_ samples: [Float], amount: Double, detune: Double) -> [Float] {
        var output = samples
        var phase1: Float = 0
        var phase2: Float = 0
        var envelope: Float = 0

        for i in 0..<output.count {
            // Envelope
            let target = abs(samples[i])
            envelope = envelope * 0.9999 + target * 0.0001

            // Two detuned partials
            phase1 += 0.01 * (1 + Float(detune) * 0.1)
            phase2 += 0.01 * (1 - Float(detune) * 0.1)
            if phase1 >= 1 { phase1 -= 1 }
            if phase2 >= 1 { phase2 -= 1 }

            let shimmer = (sin(phase1 * 2 * .pi) + sin(phase2 * 2 * .pi)) * 0.5
            output[i] += shimmer * Float(amount) * envelope * 0.2
        }

        return output
    }

    // MARK: - Generic Acoustic Processing

    private func processGenericAcoustic(_ samples: [Float], params: CharacterParameters) -> [Float] {
        var output = samples

        // Basic warmth/brightness
        if params.warmth > 0.5 {
            output = applyWarmth(output, amount: (params.warmth - 0.5) * 2)
        }

        if params.brightness > 0.5 {
            output = applyBrightness(output, amount: (params.brightness - 0.5) * 2)
        }

        return output
    }

    // MARK: - Common Processing Functions

    private func applyVibrato(_ samples: [Float], depth: Double, rate: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)

        for i in 0..<samples.count {
            let phase = Double(i) / 44100 * rate * 2 * .pi
            let pitchMod = 1.0 + sin(phase) * depth * 0.02
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

    private func applyTremolo(_ samples: [Float], rate: Double, depth: Double) -> [Float] {
        var output = samples

        for i in 0..<output.count {
            let phase = Double(i) / 44100 * rate * 2 * .pi
            let mod = Float(1.0 - depth * 0.5 * (1 - sin(phase)))
            output[i] *= mod
        }

        return output
    }

    private func applyResonantBoost(_ samples: [Float], frequency: Float, q: Float, gain: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        var z1: Float = 0, z2: Float = 0

        let omega = 2 * Float.pi * frequency / 44100
        let alpha = sin(omega) / (2 * q)
        let A = pow(10, gain / 40)

        let b0 = 1 + alpha * A
        let b1: Float = -2 * cos(omega)
        let b2 = 1 - alpha * A
        let a0 = 1 + alpha / A
        let a1: Float = -2 * cos(omega)
        let a2 = 1 - alpha / A

        for i in 0..<samples.count {
            let input = samples[i]
            let filtered = (b0/a0) * input + (b1/a0) * z1 + (b2/a0) * z2
                          - (a1/a0) * output[max(0, i-1)] - (a2/a0) * output[max(0, i-2)]
            z2 = z1
            z1 = input
            output[i] = filtered
        }

        return output
    }

    private func applyHighShelf(_ samples: [Float], frequency: Float, gain: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        var lp: Float = 0
        let alpha = frequency / 44100
        let gainLin = pow(10, gain / 20)

        for i in 0..<samples.count {
            lp = lp + alpha * (samples[i] - lp)
            let hp = samples[i] - lp
            output[i] = lp + hp * gainLin
        }

        return output
    }

    private func applyWarmth(_ samples: [Float], amount: Double) -> [Float] {
        return samples.map { sample in
            let x = sample * Float(1 + amount * 0.3)
            return tanh(x) * Float(1 / (1 + amount * 0.1))
        }
    }

    private func applyBrightness(_ samples: [Float], amount: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        var prev: Float = 0

        for i in 0..<samples.count {
            let highpass = samples[i] - prev
            prev = samples[i]
            output[i] = samples[i] + highpass * Float(amount * 0.5)
        }

        return output
    }
}

// MARK: - String Physical Model

public class StringPhysicalModel {
    private var delayLine: [Float] = []
    private var position: Int = 0

    public init() {
        delayLine = [Float](repeating: 0, count: 4410) // Up to ~10Hz fundamental
    }

    public func process(_ samples: [Float], tension: Double, damping: Double) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let dampingCoef = Float(1 - damping * 0.01)

        for i in 0..<samples.count {
            // Excite string
            delayLine[position] += samples[i] * 0.1

            // Read from delay line (string reflection)
            let readPos = (position + delayLine.count / 2) % delayLine.count
            let delayed = delayLine[readPos]

            // Lowpass filter (damping)
            let filtered = delayed * dampingCoef

            // Write back
            delayLine[position] = filtered

            output[i] = samples[i] * 0.7 + delayed * 0.3

            position = (position + 1) % delayLine.count
        }

        return output
    }

    public func processPlucked(_ samples: [Float], position pluckPos: Double, damping: Double) -> [Float] {
        var output = samples

        // Pluck position affects harmonic content
        // Plucking near bridge = more harmonics
        // Plucking at middle = fewer harmonics

        let harmonicEmphasis = Float(1 - pluckPos) // 0 = bridge, 1 = middle

        // Simple comb filter to simulate pluck position
        let delay = Int((1 - pluckPos) * 100) + 10
        for i in delay..<output.count {
            let comb = output[i] + output[i - delay] * harmonicEmphasis * 0.3
            output[i] = comb
        }

        // Damping via lowpass
        var lp: Float = 0
        let alpha = Float(damping * 0.1 + 0.05)
        for i in 0..<output.count {
            lp = lp + alpha * (output[i] - lp)
            output[i] = lp
        }

        return output
    }
}

// MARK: - Brass Physical Model

public class BrassPhysicalModel {
    public func process(_ samples: [Float], bellSize: Double) -> [Float] {
        var output = samples

        // Bell flare simulation (high frequency emphasis at bell)
        let flareFreq = Float(1000 + bellSize * 3000)
        output = applyBellFlare(output, frequency: flareFreq)

        // Bore resonances
        output = applyBoreResonances(output)

        return output
    }

    private func applyBellFlare(_ samples: [Float], frequency: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        var hp: Float = 0
        let alpha = frequency / 44100

        for i in 0..<samples.count {
            hp = hp + alpha * (samples[i] - hp)
            let highpass = samples[i] - hp
            output[i] = samples[i] + highpass * 0.3
        }

        return output
    }

    private func applyBoreResonances(_ samples: [Float]) -> [Float] {
        var output = samples

        // Characteristic brass formants
        let formants: [(Float, Float)] = [(500, 3), (1200, 4), (2000, 3)]

        for (freq, q) in formants {
            var z1: Float = 0, z2: Float = 0
            let omega = 2 * Float.pi * freq / 44100
            let alpha = sin(omega) / (2 * q)

            for i in 0..<output.count {
                let bp = alpha * (samples[i] - z2)
                z2 = z1
                z1 = samples[i]
                output[i] += bp * 0.1
            }
        }

        return output
    }
}

// MARK: - Woodwind Physical Model

public class WoodwindPhysicalModel {
    public func process(_ samples: [Float], boreLength: Double) -> [Float] {
        var output = samples

        // Tone hole simulation (register changes)
        output = applyToneHoles(output, openness: 0.5)

        // Bore resonances (different from brass)
        output = applyWoodwindResonances(output)

        return output
    }

    private func applyToneHoles(_ samples: [Float], openness: Double) -> [Float] {
        // Simplified - affects overtone structure
        var output = samples
        let cutoff = Float(2000 + openness * 6000)
        var lp: Float = 0
        let alpha = cutoff / 44100

        for i in 0..<output.count {
            lp = lp + alpha * (output[i] - lp)
            output[i] = lp * 0.7 + output[i] * 0.3
        }

        return output
    }

    private func applyWoodwindResonances(_ samples: [Float]) -> [Float] {
        var output = samples

        // Woodwind characteristic: odd harmonics emphasized
        var phase: Float = 0
        for i in 0..<output.count {
            phase += 0.001
            if phase >= 1 { phase -= 1 }
            // Add subtle odd harmonic content
            let oddHarmonic = sin(phase * 2 * .pi * 3) * 0.05
            output[i] += oddHarmonic * abs(samples[i])
        }

        return output
    }
}

// MARK: - Percussion Model

public class PercussionModel {
    public func generateHammerImpact(count: Int, hardness: Double) -> [Float] {
        var output = [Float](repeating: 0, count: count)

        // Impact transient
        let impactLength = Int((1 - hardness) * 500) + 50

        for i in 0..<min(impactLength, count) {
            let progress = Float(i) / Float(impactLength)
            // Exponential decay with high frequency content
            let envelope = exp(-progress * 5)
            let noise = Float.random(in: -1...1) * Float(hardness)
            output[i] = envelope * (noise * 0.3 + sin(progress * 100) * 0.7)
        }

        return output
    }

    public func addBellResonance(_ samples: [Float], brightness: Double) -> [Float] {
        var output = samples

        // Multiple inharmonic partials for bell character
        let partials: [Float] = [1.0, 2.0, 2.4, 3.0, 4.2, 5.4]
        let baseFreq: Float = 500

        for partial in partials {
            var phase: Float = Float.random(in: 0..<1)
            var envelope: Float = 0

            for i in 0..<output.count {
                // Envelope follower
                let target = abs(samples[i])
                if target > envelope {
                    envelope = target
                } else {
                    envelope *= 0.9998
                }

                phase += baseFreq * partial / 44100
                if phase >= 1 { phase -= 1 }

                let partialSound = sin(phase * 2 * .pi) * envelope
                output[i] += partialSound * Float(brightness) * 0.05
            }
        }

        return output
    }
}

// MARK: - Instrument Body Resonator

public class InstrumentBodyResonator {
    public func process(_ samples: [Float], resonance: Double) -> [Float] {
        var output = samples

        // Body modes
        let modes: [(Float, Float, Float)] = [
            (150, 5, 0.2),   // Air mode
            (280, 8, 0.15),  // Main body
            (500, 6, 0.1),   // Top plate
        ]

        for (freq, q, gain) in modes {
            var z1: Float = 0, z2: Float = 0
            let omega = 2 * Float.pi * freq / 44100
            let alpha = sin(omega) / (2 * q)

            for i in 0..<output.count {
                let input = samples[i]
                let bp = alpha * input - alpha * z2
                z2 = z1
                z1 = input
                output[i] += bp * gain * Float(resonance)
            }
        }

        return output
    }
}

// MARK: - Excitation Generator

public class ExcitationGenerator {
    private var noiseBuffer: [Float] = []

    public init() {
        noiseBuffer = (0..<44100).map { _ in Float.random(in: -1...1) }
    }

    public func generateBow(count: Int, pressure: Double, speed: Double) -> [Float] {
        var output = [Float](repeating: 0, count: count)

        // Bow noise with stick-slip character
        var position = Int.random(in: 0..<noiseBuffer.count)
        var stickSlipPhase: Float = 0

        for i in 0..<count {
            // Stick-slip oscillation
            stickSlipPhase += Float(speed) * 0.01
            if stickSlipPhase >= 1 { stickSlipPhase -= 1 }
            let stickSlip = stickSlipPhase < Float(pressure) ? Float(1) : Float(-0.5)

            // Filtered noise
            let noise = noiseBuffer[position]
            position = (position + 1) % noiseBuffer.count

            output[i] = (stickSlip * 0.7 + noise * 0.3) * Float(pressure)
        }

        return output
    }

    public func generateLipBuzz(count: Int, tension: Double, airPressure: Double) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        var phase: Float = 0
        let freq = Float(100 + tension * 200) // Lip frequency

        for i in 0..<count {
            phase += freq / 44100
            if phase >= 1 { phase -= 1 }

            // Asymmetric waveform for lip buzz
            let buzz: Float
            if phase < 0.3 {
                buzz = phase / 0.3
            } else {
                buzz = 1 - (phase - 0.3) / 0.7
            }

            output[i] = buzz * Float(airPressure)
        }

        return output
    }

    public func generateBreath(count: Int, intensity: Double) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        var position = Int.random(in: 0..<noiseBuffer.count)
        var filtered: Float = 0

        // Bandpass filtered noise for breath
        let alpha: Float = 0.1

        for i in 0..<count {
            let noise = noiseBuffer[position]
            position = (position + 1) % noiseBuffer.count

            filtered = filtered + alpha * (noise - filtered)
            output[i] = filtered * Float(intensity)
        }

        return output
    }
}

// MARK: - Acoustic Room Simulator

public class AcousticRoomSimulator {
    private var delayLines: [[Float]] = []
    private var positions: [Int] = []

    public init() {
        // Multiple delay lines for early reflections
        let delays = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116]
        for delay in delays {
            delayLines.append([Float](repeating: 0, count: delay))
            positions.append(0)
        }
    }

    public func process(_ samples: [Float], amount: Double, size: Double) -> [Float] {
        var wet = [Float](repeating: 0, count: samples.count)
        let feedback = Float(0.7 + size * 0.25)

        // Parallel comb filters
        for d in 0..<delayLines.count {
            for i in 0..<samples.count {
                let delayed = delayLines[d][positions[d]]
                let input = samples[i] + delayed * feedback
                delayLines[d][positions[d]] = input * 0.5
                positions[d] = (positions[d] + 1) % delayLines[d].count
                wet[i] += delayed / Float(delayLines.count)
            }
        }

        // Mix
        var output = [Float](repeating: 0, count: samples.count)
        let wetGain = Float(amount)
        let dryGain = Float(1 - amount * 0.5)

        for i in 0..<samples.count {
            output[i] = samples[i] * dryGain + wet[i] * wetGain
        }

        return output
    }
}
