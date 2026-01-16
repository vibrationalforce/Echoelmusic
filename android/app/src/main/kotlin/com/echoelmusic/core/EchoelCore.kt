package com.echoelmusic.core

import kotlin.math.*
import kotlin.random.Random

/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                                                                           ║
 * ║   ███████╗ ██████╗██╗  ██╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ║
 * ║   ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝██║     ██╔════╝██╔═══██╗██╔══██╗║
 * ║   █████╗  ██║     ███████║██║   ██║█████╗  ██║     ██║     ██║   ██║██████╔╝║
 * ║   ██╔══╝  ██║     ██╔══██║██║   ██║██╔══╝  ██║     ██║     ██║   ██║██╔══██╗║
 * ║   ███████╗╚██████╗██║  ██║╚██████╔╝███████╗███████╗╚██████╗╚██████╔╝██║  ██║║
 * ║   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝║
 * ║                                                                           ║
 * ║   🎵 Pure Native DSP - No JUCE, No Dependencies, Just Vibes 🎵            ║
 * ║   Cross-Platform: iOS • macOS • watchOS • tvOS • visionOS • Android       ║
 * ║                                                                           ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 */

// MARK: - EchoelCore Configuration

object EchoelCore {
    const val VERSION = "1.0.0"
    const val DEFAULT_SAMPLE_RATE = 48000f
    const val IDENTIFIER = "com.echoelmusic.core"
    const val MOTTO = "breath → sound → light → consciousness ✨"
}

// MARK: - 🔥 EchoelWarmth - Analog Hardware Emulations

object EchoelWarmth {

    enum class Legend(val displayName: String, val emoji: String, val vibe: String) {
        SSL("SSL Glue", "🔵", "Punchy. Glue. Modern."),
        API("API Punch", "⚫", "Thrust. Power. Drums."),
        NEVE("Neve Magic", "🔷", "Silk. Warmth. Magic."),
        PULTEC("Pultec Silk", "🟡", "Air. Bottom. Classic."),
        FAIRCHILD("Fairchild Dream", "⚪", "Smooth. Vintage. Rare."),
        LA2A("LA-2A Love", "🪩", "Vocals. Bass. Butter."),
        ELEVEN76("1176 Bite", "🖤", "Fast. Aggressive. Bite."),
        MANLEY("Manley Velvet", "🟠", "Master. Tube. Velvet.")
    }

    class TheConsole(private val sampleRate: Float = EchoelCore.DEFAULT_SAMPLE_RATE) {

        var vibe: Float = 50f
        var legend: Legend = Legend.NEVE
        var output: Float = 50f
        var blend: Float = 100f
        var bypassed: Boolean = false

        fun process(input: FloatArray): FloatArray {
            if (bypassed) return input

            val processed = applyLegend(input)
            val outputGain = 10f.pow((output - 50f) / 50f * 12f / 20f)
            val wet = blend / 100f

            return FloatArray(input.size) { i ->
                val wetSignal = processed[i] * outputGain
                input[i] * (1f - wet) + wetSignal * wet
            }
        }

        private fun applyLegend(input: FloatArray): FloatArray {
            val amount = vibe / 100f

            return FloatArray(input.size) { i ->
                var out = input[i]

                when (legend) {
                    Legend.SSL -> {
                        val threshold = 0.3f - amount * 0.2f
                        if (abs(out) > threshold) {
                            val excess = abs(out) - threshold
                            val compressed = threshold + excess / (1f + excess * 3f * amount)
                            out = if (out > 0) compressed else -compressed
                        }
                    }
                    Legend.API -> {
                        out = tanh(out * (1f + amount * 2f)) * (0.9f + amount * 0.1f)
                    }
                    Legend.NEVE -> {
                        val second = out * out * 0.15f * amount
                        val fourth = out * out * out * out * 0.05f * amount
                        out = out + (if (out > 0) second + fourth else -second - fourth)
                        out = out / (1f + abs(out) * amount * 0.1f)
                    }
                    Legend.PULTEC -> {
                        out = out * (1f + amount * 0.3f)
                    }
                    Legend.FAIRCHILD -> {
                        val level = abs(out)
                        if (level > 0.2f) {
                            val ratio = 2f + level * amount * 4f
                            out = out / (1f + level * (ratio - 1f) * amount)
                        }
                    }
                    Legend.LA2A -> {
                        out = out / (1f + abs(out) * amount * 0.5f)
                    }
                    Legend.ELEVEN76 -> {
                        out = tanh(out * (1f + amount * 3f))
                        out = out + out * out * out * 0.1f * amount
                    }
                    Legend.MANLEY -> {
                        out = if (out >= 0) {
                            out / (1f + out * amount * 0.4f)
                        } else {
                            out / (1f - out * amount * 0.3f)
                        }
                    }
                }

                out
            }
        }
    }
}

// MARK: - 🌱 EchoelSeed - Genetic Sound Evolution

object EchoelSeed {

    data class SoundDNA(
        var genes: FloatArray = FloatArray(16) { Random.nextFloat() },
        var attack: Float = Random.nextFloat() * 0.5f + 0.001f,
        var decay: Float = Random.nextFloat() * 1.9f + 0.1f,
        var brightness: Float = Random.nextFloat() * 0.8f + 0.2f,
        var movement: Float = Random.nextFloat() * 0.5f,
        var mutationRate: Float = Random.nextFloat() * 0.1f,
        var generation: Int = 0
    ) {
        companion object {
            fun randomSeed() = SoundDNA()
        }

        fun breed(partner: SoundDNA): SoundDNA {
            val child = SoundDNA()
            child.generation = maxOf(generation, partner.generation) + 1

            for (i in 0 until 16) {
                child.genes[i] = if (Random.nextBoolean()) genes[i] else partner.genes[i]
                if (Random.nextFloat() < mutationRate) {
                    child.genes[i] = Random.nextFloat()
                }
            }

            child.attack = (attack + partner.attack) / 2f
            child.decay = (decay + partner.decay) / 2f
            child.brightness = (brightness + partner.brightness) / 2f
            child.movement = (movement + partner.movement) / 2f
            child.mutationRate = (mutationRate + partner.mutationRate) / 2f

            return child
        }
    }

    class Garden(private val sampleRate: Float = EchoelCore.DEFAULT_SAMPLE_RATE) {

        var dna: SoundDNA = SoundDNA.randomSeed()
        var frequency: Float = 440f
        var volume: Float = 0.8f

        private var phase: Float = 0f
        private var envelope: Float = 0f
        private var lfoPhase: Float = 0f

        fun plantSeed() {
            dna = SoundDNA.randomSeed()
            phase = 0f
            envelope = 0f
        }

        fun mutate(chaos: Float = 0.1f) {
            for (i in dna.genes.indices) {
                if (Random.nextFloat() < chaos) {
                    dna.genes[i] = Random.nextFloat()
                }
            }
            dna.generation++
        }

        fun breed(partner: SoundDNA) {
            dna = dna.breed(partner)
        }

        fun grow(frameCount: Int): FloatArray {
            val output = FloatArray(frameCount)
            val phaseIncrement = frequency / sampleRate

            for (i in 0 until frameCount) {
                lfoPhase += 2f * PI.toFloat() * 2f / sampleRate
                val lfo = sin(lfoPhase) * dna.movement

                var sample = 0f
                for ((harmonic, gene) in dna.genes.withIndex()) {
                    val harmonicPhase = phase * (harmonic + 1)
                    sample += sin(harmonicPhase * 2f * PI.toFloat()) * gene / (harmonic + 1)
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
    }
}

// MARK: - 💓 EchoelPulse - Bio-Reactive Audio

object EchoelPulse {

    data class BodyMusic(
        var heartRate: Float = 70f,
        var hrv: Float = 50f,
        var coherence: Float = 50f,
        var breathRate: Float = 12f,
        var breathPhase: Float = 0f
    )

    class HeartSync(private val sampleRate: Float = EchoelCore.DEFAULT_SAMPLE_RATE) {

        var body: BodyMusic = BodyMusic()

        var filterCutoff: Float = 1000f
            private set
        var reverbAmount: Float = 0.3f
            private set
        var delayTime: Float = 500f
            private set
        var warmth: Float = 0.2f
            private set

        fun sync(body: BodyMusic) {
            this.body = body

            val hrNorm = ((body.heartRate - 60f) / 60f).coerceIn(0f, 1f)
            filterCutoff = 500f + hrNorm * 4500f

            val hrvNorm = ((body.hrv - 20f) / 80f).coerceIn(0f, 1f)
            reverbAmount = 0.1f + hrvNorm * 0.6f

            val cohNorm = body.coherence / 100f
            warmth = cohNorm * 0.4f

            val breathNorm = ((20f - body.breathRate) / 14f).coerceIn(0f, 1f)
            delayTime = 200f + breathNorm * 800f
        }

        fun process(input: FloatArray): FloatArray {
            val output = input.copyOf()

            val breathEnvelope = 0.8f + body.breathPhase * 0.2f
            for (i in output.indices) {
                output[i] *= breathEnvelope
            }

            if (warmth > 0.01f) {
                for (i in output.indices) {
                    output[i] = tanh(output[i] * (1f + warmth * 2f)) / (1f + warmth)
                }
            }

            return output
        }
    }
}

// MARK: - 🎨 EchoelVibe - Creative Effects

object EchoelVibe {

    enum class SaturationFlavor(val displayName: String, val emoji: String) {
        WARM("Warm Hug", "🤗"),
        AGGRESSIVE("Angry Cat", "😾"),
        CLEAN("Glass of Water", "💧"),
        CRUNCHY("Broken Speaker", "📢"),
        NUCLEAR("Chernobyl", "☢️")
    }

    class ThePunisher(private val sampleRate: Float = EchoelCore.DEFAULT_SAMPLE_RATE) {

        var drive: Float = 50f
        var flavor: SaturationFlavor = SaturationFlavor.WARM
        var punish: Boolean = false
        var tone: Float = 50f
        var blend: Float = 100f

        fun process(input: FloatArray): FloatArray {
            val driveAmount = (drive / 100f) * (if (punish) 3f else 1f)
            val wet = blend / 100f

            return FloatArray(input.size) { i ->
                val sample = input[i]
                val driven = sample * (1f + driveAmount * 5f)

                val saturated = when (flavor) {
                    SaturationFlavor.WARM -> {
                        val norm = driven / (1f + abs(driven) * 0.3f)
                        val second = norm * norm * 0.15f
                        norm + (if (driven > 0) second else -second)
                    }
                    SaturationFlavor.AGGRESSIVE -> {
                        if (driven >= 0) tanh(driven * 1.5f) else tanh(driven * 1.2f) * 0.9f
                    }
                    SaturationFlavor.CLEAN -> {
                        driven / (1f + abs(driven) * 0.1f)
                    }
                    SaturationFlavor.CRUNCHY -> {
                        val threshold = 0.7f
                        if (abs(driven) < threshold) {
                            driven
                        } else {
                            val sign = if (driven > 0) 1f else -1f
                            val excess = abs(driven) - threshold
                            sign * (threshold + excess / (1f + excess * 3f))
                        }
                    }
                    SaturationFlavor.NUCLEAR -> {
                        val clipped = driven.coerceIn(-1f, 1f) * 2f
                        clipped + clipped * clipped * clipped * 0.3f
                    }
                }

                val toneAmount = (tone - 50f) / 50f
                val toned = saturated * (1f + toneAmount * 0.3f)

                sample * (1f - wet) + toned * wet
            }
        }
    }

    enum class EchoStyle(val displayName: String, val emoji: String) {
        DIGITAL("Crystal Clear", "💎"),
        TAPE("Grandpa's Reel", "📼"),
        ANALOG("Bucket Brigade", "🪣"),
        LOFI("Broken Walkman", "📻"),
        SPACE("Event Horizon", "🕳️")
    }

    class TheTimeMachine(private val sampleRate: Float = EchoelCore.DEFAULT_SAMPLE_RATE) {

        var time: Float = 500f
        var feedback: Float = 40f
        var style: EchoStyle = EchoStyle.TAPE
        var wobble: Float = 10f
        var warmth: Float = 20f
        var blend: Float = 30f

        private var buffer: FloatArray
        private var writePos: Int = 0
        private var modPhase: Float = 0f

        init {
            val maxSamples = (3000f * sampleRate / 1000f).toInt()
            buffer = FloatArray(maxSamples)
        }

        fun process(input: FloatArray): FloatArray {
            val output = FloatArray(input.size)
            val delaySamples = (time * sampleRate / 1000f).toInt()
            val fbAmount = feedback / 100f
            val wet = blend / 100f

            for (i in input.indices) {
                val modAmount = wobble / 100f * delaySamples * 0.02f
                modPhase += 2f * PI.toFloat() * 0.5f / sampleRate
                val modOffset = (sin(modPhase) * modAmount).toInt()

                val actualDelay = maxOf(1, delaySamples + modOffset)
                val readPos = (writePos - actualDelay + buffer.size) % buffer.size

                var delayed = buffer[readPos]
                delayed = applyStyle(delayed)

                if (warmth > 0) {
                    delayed = tanh(delayed * (1f + warmth / 50f)) / (1f + warmth / 100f)
                }

                buffer[writePos] = input[i] + delayed * fbAmount
                output[i] = input[i] * (1f - wet) + delayed * wet

                writePos = (writePos + 1) % buffer.size
            }

            return output
        }

        private fun applyStyle(x: Float): Float = when (style) {
            EchoStyle.DIGITAL -> x
            EchoStyle.TAPE -> tanh(x * 1.2f) * 0.95f
            EchoStyle.ANALOG -> (x * 128f).roundToInt() / 128f * 0.98f
            EchoStyle.LOFI -> (x * 32f).roundToInt() / 32f * 0.85f
            EchoStyle.SPACE -> x * 0.9f
        }
    }

    class TheVoiceChanger(private val sampleRate: Float = EchoelCore.DEFAULT_SAMPLE_RATE) {

        var pitch: Float = 0f
        var formant: Float = 0f
        var robot: Boolean = false
        var blend: Float = 100f

        private var robotPhase: Float = 0f
        private var inputBuffer: FloatArray = FloatArray(2048)
        private var grainPos: Int = 0

        fun process(input: FloatArray): FloatArray {
            val pitchRatio = 2f.pow(pitch / 12f)
            val wet = blend / 100f

            return FloatArray(input.size) { i ->
                val sample = input[i]
                var processed = sample

                if (abs(pitch) > 0.1f) {
                    inputBuffer[grainPos] = sample
                    grainPos = (grainPos + 1) % inputBuffer.size
                    val readPos = grainPos / pitchRatio
                    processed = inputBuffer[readPos.toInt() % inputBuffer.size]
                }

                if (abs(formant) > 1f) {
                    processed *= (1f + formant / 100f * 0.2f)
                }

                if (robot) {
                    robotPhase += 2f * PI.toFloat() * 200f / sampleRate
                    if (robotPhase > 2f * PI.toFloat()) robotPhase -= 2f * PI.toFloat()
                    processed = abs(processed) * sin(robotPhase) * 2f
                }

                sample * (1f - wet) + processed * wet
            }
        }
    }
}
