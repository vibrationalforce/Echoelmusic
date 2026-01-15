package com.echoelmusic.dsp

import kotlin.math.*
import kotlin.random.Random

/**
 * Soundtoys-Inspired DSP Effects for Android
 * Cross-Platform Support: Android 8+ (API 26+)
 * iOS/Swift equivalent: Sources/Echoelmusic/DSP/AdvancedDSPEffects.swift
 *
 * Inspired by:
 * - Soundtoys Decapitator (saturation)
 * - Soundtoys EchoBoy (delay)
 * - Soundtoys Little AlterBoy (formant/pitch)
 * - Sonic Charge Synplant (genetic synthesis)
 */

// MARK: - Decapitator-Style Saturation

/**
 * Analog saturation with 5 character modes
 * Inspired by Soundtoys Decapitator
 */
class DecapitatorSaturation(private val sampleRate: Float = 48000f) {

    enum class Style(val displayName: String) {
        A("Tube A"),           // Warm tube preamp (Neve-like)
        E("Tube E"),           // Aggressive tube amp (Marshall-like)
        N("Tube N"),           // Clean tube warmth (API-like)
        T("Transistor"),       // Solid-state crunch (SSL-like)
        P("Pentode")           // Heavy tube distortion
    }

    var drive: Float = 50f         // 0-100
    var mix: Float = 100f          // Dry/wet
    var output: Float = 0f         // dB
    var lowCut: Float = 20f        // Hz
    var highCut: Float = 20000f    // Hz
    var tone: Float = 50f          // Low to high emphasis
    var punish: Boolean = false    // Extreme mode
    var style: Style = Style.A

    fun process(input: FloatArray): FloatArray {
        val result = FloatArray(input.size)
        val driveAmount = (drive / 100f) * (if (punish) 3f else 1f)
        val outputGain = 10f.pow(output / 20f)
        val wetAmount = mix / 100f

        for (i in input.indices) {
            val driven = input[i] * (1f + driveAmount * 5f)

            val saturated = when (style) {
                Style.A -> tubeWarmSaturation(driven)
                Style.E -> tubeAggressiveSaturation(driven)
                Style.N -> tubeCleanSaturation(driven)
                Style.T -> transistorSaturation(driven)
                Style.P -> pentodeSaturation(driven)
            }

            val toned = applyTone(saturated)
            val wet = toned * outputGain
            result[i] = input[i] * (1f - wetAmount) + wet * wetAmount
        }

        return result
    }

    private fun tubeWarmSaturation(x: Float): Float {
        val normalized = x / (1f + abs(x) * 0.3f)
        val second = normalized * normalized * 0.15f
        val fourth = normalized * normalized * normalized * normalized * 0.05f
        return normalized + (if (x > 0) second + fourth else -second - fourth)
    }

    private fun tubeAggressiveSaturation(x: Float): Float {
        return if (x >= 0) tanh(x * 1.5f) else tanh(x * 1.2f) * 0.9f
    }

    private fun tubeCleanSaturation(x: Float): Float {
        return x / (1f + abs(x) * 0.1f)
    }

    private fun transistorSaturation(x: Float): Float {
        val threshold = 0.7f
        return if (abs(x) < threshold) {
            x
        } else {
            val sign = if (x > 0) 1f else -1f
            val excess = abs(x) - threshold
            sign * (threshold + excess / (1f + excess * 3f))
        }
    }

    private fun pentodeSaturation(x: Float): Float {
        val driven = x * 2f
        val clipped = driven.coerceIn(-1f, 1f)
        return clipped + clipped * clipped * clipped * 0.3f
    }

    private fun applyTone(x: Float): Float {
        val toneAmount = (tone - 50f) / 50f
        return x * (1f + toneAmount * 0.3f)
    }
}

// MARK: - EchoBoy-Style Delay

/**
 * Multi-character delay with vintage emulations
 * Inspired by Soundtoys EchoBoy
 */
class EchoBoyDelay(private val sampleRate: Float = 48000f) {

    enum class Style(val displayName: String) {
        DIGITAL("Digital"),
        TAPE("Tape"),
        ANALOG("Analog"),
        DIFFUSED("Diffused"),
        SINGLE_TAPE("Single Tape"),
        DUAL_TAPE("Dual Tape"),
        STUDIO("Studio"),
        LO_FI("Lo-Fi")
    }

    var delayTime: Float = 500f    // ms
    var feedback: Float = 40f      // 0-100
    var mix: Float = 30f           // Dry/wet
    var saturation: Float = 20f    // Analog warmth
    var modulation: Float = 10f    // Wow/flutter
    var highCut: Float = 8000f     // Hz
    var lowCut: Float = 100f       // Hz
    var style: Style = Style.TAPE

    private var delayBuffer: FloatArray
    private var writePosition: Int = 0
    private var modPhase: Float = 0f

    init {
        val maxSamples = (3000f * sampleRate / 1000f).toInt()
        delayBuffer = FloatArray(maxSamples)
    }

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val delaySamples = (delayTime * sampleRate / 1000f).toInt()
        val feedbackAmount = feedback / 100f
        val wetAmount = mix / 100f

        for (i in input.indices) {
            // Modulation (wow/flutter)
            val modAmount = modulation / 100f * delaySamples * 0.02f
            modPhase += 2f * PI.toFloat() * 0.5f / sampleRate
            val modOffset = (sin(modPhase) * modAmount).toInt()

            val actualDelay = maxOf(1, delaySamples + modOffset)
            val readPosition = (writePosition - actualDelay + delayBuffer.size) % delayBuffer.size

            var delayed = delayBuffer[readPosition]
            delayed = applyStyle(delayed)

            if (saturation > 0) {
                delayed = tanh(delayed * (1f + saturation / 50f)) / (1f + saturation / 100f)
            }

            delayBuffer[writePosition] = input[i] + delayed * feedbackAmount
            output[i] = input[i] * (1f - wetAmount) + delayed * wetAmount

            writePosition = (writePosition + 1) % delayBuffer.size
        }

        return output
    }

    private fun applyStyle(x: Float): Float = when (style) {
        Style.DIGITAL -> x
        Style.TAPE -> tanh(x * 1.2f) * 0.95f
        Style.ANALOG -> (x * 128f).roundToInt() / 128f * 0.98f
        Style.DIFFUSED -> x * 0.9f
        Style.SINGLE_TAPE -> tanh(x) * 0.97f
        Style.DUAL_TAPE -> tanh(x * 1.1f) * 0.96f
        Style.STUDIO -> x * 0.99f
        Style.LO_FI -> (x * 32f).roundToInt() / 32f * 0.85f
    }
}

// MARK: - Little AlterBoy-Style Voice Changer

/**
 * Formant and pitch shifting for voice transformation
 * Inspired by Soundtoys Little AlterBoy
 */
class LittleAlterBoy(private val sampleRate: Float = 48000f) {

    var pitch: Float = 0f          // Semitones (-12 to +12)
    var formant: Float = 0f        // -100 to +100
    var mix: Float = 100f          // Dry/wet
    var drive: Float = 0f          // Saturation
    var robotMode: Boolean = false

    private var phaseAccumulator: Float = 0f
    private var inputBuffer: FloatArray = FloatArray(2048)
    private var grainPosition: Int = 0

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val pitchRatio = 2f.pow(pitch / 12f)
        val wetAmount = mix / 100f

        for (i in input.indices) {
            var processed = input[i]

            if (abs(pitch) > 0.1f) {
                processed = simplePitchShift(processed, pitchRatio)
            }

            if (abs(formant) > 1f) {
                processed = applyFormantShift(processed)
            }

            if (robotMode) {
                processed = applyRobotEffect(processed)
            }

            if (drive > 0) {
                val driveAmount = drive / 100f
                processed = tanh(processed * (1f + driveAmount * 3f))
            }

            output[i] = input[i] * (1f - wetAmount) + processed * wetAmount
        }

        return output
    }

    private fun simplePitchShift(x: Float, ratio: Float): Float {
        inputBuffer[grainPosition] = x
        grainPosition = (grainPosition + 1) % inputBuffer.size

        val readPos = grainPosition / ratio
        val readIndex = readPos.toInt() % inputBuffer.size
        return inputBuffer[readIndex]
    }

    private fun applyFormantShift(x: Float): Float {
        val shiftAmount = formant / 100f
        return x * (1f + shiftAmount * 0.2f)
    }

    private fun applyRobotEffect(x: Float): Float {
        phaseAccumulator += 2f * PI.toFloat() * 200f / sampleRate
        if (phaseAccumulator > 2f * PI.toFloat()) {
            phaseAccumulator -= 2f * PI.toFloat()
        }
        return abs(x) * sin(phaseAccumulator) * 2f
    }
}

// MARK: - Genetic Synthesizer (Synplant-inspired)

/**
 * Sounds that evolve and mutate from seeds
 * Inspired by Sonic Charge Synplant
 */
class GeneticSynthesizer(private val sampleRate: Float = 48000f) {

    data class SoundDNA(
        var harmonics: FloatArray = FloatArray(16) { Random.nextFloat() },
        var attack: Float = Random.nextFloat() * 0.5f + 0.001f,
        var decay: Float = Random.nextFloat() * 1.9f + 0.1f,
        var brightness: Float = Random.nextFloat() * 0.8f + 0.2f,
        var movement: Float = Random.nextFloat() * 0.5f,
        var mutation: Float = Random.nextFloat() * 0.1f,
        var generation: Int = 0
    ) {
        fun breed(other: SoundDNA): SoundDNA {
            val child = SoundDNA()
            child.generation = maxOf(generation, other.generation) + 1

            for (i in 0 until 16) {
                child.harmonics[i] = if (Random.nextBoolean()) harmonics[i] else other.harmonics[i]
                if (Random.nextFloat() < mutation) {
                    child.harmonics[i] = Random.nextFloat()
                }
            }

            child.attack = (attack + other.attack) / 2f
            child.decay = (decay + other.decay) / 2f
            child.brightness = (brightness + other.brightness) / 2f
            child.movement = (movement + other.movement) / 2f
            child.mutation = (mutation + other.mutation) / 2f

            return child
        }
    }

    var dna: SoundDNA = SoundDNA()
    var frequency: Float = 440f
    var volume: Float = 0.8f

    private var phase: Float = 0f
    private var envelope: Float = 0f
    private var lfoPhase: Float = 0f

    fun generate(frameCount: Int): FloatArray {
        val output = FloatArray(frameCount)
        val phaseIncrement = frequency / sampleRate

        for (i in 0 until frameCount) {
            lfoPhase += 2f * PI.toFloat() * 2f / sampleRate
            val lfo = sin(lfoPhase) * dna.movement

            var sample = 0f
            for ((harmonic, level) in dna.harmonics.withIndex()) {
                val harmonicPhase = phase * (harmonic + 1)
                sample += sin(harmonicPhase * 2f * PI.toFloat()) * level / (harmonic + 1)
            }

            val filtered = sample * dna.brightness + sample * (1f - dna.brightness) * 0.3f
            val modulated = filtered * (1f + lfo)

            envelope = maxOf(0f, envelope * (1f - 1f / (dna.decay * sampleRate)))
            output[i] = modulated * envelope * volume

            phase += phaseIncrement
            if (phase > 1f) phase -= 1f
        }

        return output
    }

    fun noteOn() {
        envelope = 1f
    }

    fun mutate(amount: Float = 0.1f) {
        for (i in dna.harmonics.indices) {
            if (Random.nextFloat() < amount) {
                dna.harmonics[i] = Random.nextFloat()
            }
        }
        dna.generation++
    }

    fun plantSeed() {
        dna = SoundDNA()
    }

    fun grow(parents: List<SoundDNA>) {
        if (parents.size >= 2) {
            dna = parents[0].breed(parents[1])
        } else {
            dna = parents.firstOrNull() ?: SoundDNA()
        }
    }
}

// MARK: - Bio-Reactive DSP Processor

/**
 * Modulates effects based on biometric data
 * Unique to Echoelmusic
 */
class BioReactiveDSP(private val sampleRate: Float = 48000f) {

    data class BioData(
        var heartRate: Float = 70f,       // BPM
        var hrv: Float = 50f,             // SDNN ms
        var coherence: Float = 50f,       // 0-100
        var breathingRate: Float = 12f,   // BPM
        var breathPhase: Float = 0f       // 0-1 (inhale to exhale)
    )

    var bioData: BioData = BioData()

    private var filterCutoff: Float = 1000f
    private var reverbAmount: Float = 0.3f
    private var delayTime: Float = 500f
    private var saturationAmount: Float = 0.2f

    fun updateBioData(data: BioData) {
        bioData = data

        val normalizedHR = ((data.heartRate - 60f) / 60f).coerceIn(0f, 1f)
        filterCutoff = 500f + normalizedHR * 4500f

        val normalizedHRV = ((data.hrv - 20f) / 80f).coerceIn(0f, 1f)
        reverbAmount = 0.1f + normalizedHRV * 0.6f

        val normalizedCoherence = data.coherence / 100f
        saturationAmount = normalizedCoherence * 0.4f

        val normalizedBreath = ((20f - data.breathingRate) / 14f).coerceIn(0f, 1f)
        delayTime = 200f + normalizedBreath * 800f
    }

    fun process(input: FloatArray): FloatArray {
        val output = input.copyOf()

        val breathEnvelope = 0.8f + bioData.breathPhase * 0.2f
        for (i in output.indices) {
            output[i] *= breathEnvelope
        }

        if (saturationAmount > 0.01f) {
            for (i in output.indices) {
                output[i] = tanh(output[i] * (1f + saturationAmount * 2f)) / (1f + saturationAmount)
            }
        }

        return output
    }

    fun getEffectParameters(): EffectParams {
        return EffectParams(filterCutoff, reverbAmount, delayTime, saturationAmount)
    }

    data class EffectParams(
        val filter: Float,
        val reverb: Float,
        val delay: Float,
        val saturation: Float
    )
}
