package com.echoelmusic.dsp

import kotlin.math.*

/**
 * Classic Analog Hardware Emulations for Android
 * Cross-Platform Support: Android 8+ (API 26+)
 * iOS/Swift equivalent: Sources/Echoelmusic/DSP/ClassicAnalogEmulations.swift
 *
 * Supported Hardware Styles:
 * - SSL - Solid State Logic (4000E/G Bus Compressor)
 * - API - All-Pass Input (2500 Bus Compressor)
 * - Pultec - EQP-1A Passive EQ
 * - Fairchild - 670 Tube Limiter
 * - LA-2A - Teletronix Optical Compressor
 * - 1176 - UREI FET Limiter
 * - Manley - Vari-Mu Compressor
 * - Neve - 33609/MBT (see NeveInspiredDSP.kt)
 */

// MARK: - Hardware Style Enum

enum class HardwareStyle(val displayName: String, val color: String) {
    SSL("SSL 4000G Bus Compressor", "Blue"),
    API("API 2500 Stereo Compressor", "Black"),
    NEVE("Neve 33609/MBT", "Blue"),
    PULTEC("Pultec EQP-1A", "Cream"),
    FAIRCHILD("Fairchild 670", "Gray"),
    LA2A("Teletronix LA-2A", "Silver"),
    UREI1176("UREI 1176LN", "Black"),
    MANLEY("Manley Vari-Mu", "Gold");

    val isCompressor: Boolean
        get() = this != PULTEC
}

// MARK: - Unified Analog Console

/**
 * Easy-access console for switching between classic analog emulations
 * One-knob simplicity with expert mode for detailed control
 */
class AnalogConsole(private val sampleRate: Float = 48000f) {

    var currentStyle: HardwareStyle = HardwareStyle.SSL
        set(value) {
            field = value
            updateParameters()
        }

    /** Main "Character" knob (0-100%) */
    var character: Float = 50f
        set(value) {
            field = value.coerceIn(0f, 100f)
            updateParameters()
        }

    /** Output level (0-100%) */
    var output: Float = 50f

    /** Mix (dry/wet) for parallel processing */
    var mix: Float = 100f

    /** Bypass */
    var bypassed: Boolean = false

    // Internal processors
    private val sslCompressor = SSLBusCompressor(sampleRate)
    private val apiCompressor = APIBusCompressor(sampleRate)
    private val pultecEQ = PultecEQP1A(sampleRate)
    private val fairchildLimiter = FairchildLimiter(sampleRate)
    private val la2aCompressor = LA2ACompressor(sampleRate)
    private val urei1176 = UREI1176Limiter(sampleRate)
    private val manleyVariMu = ManleyVariMu(sampleRate)

    fun process(input: FloatArray): FloatArray {
        if (bypassed) return input

        val processed = when (currentStyle) {
            HardwareStyle.SSL -> sslCompressor.process(input)
            HardwareStyle.API -> apiCompressor.process(input)
            HardwareStyle.NEVE -> input // Use NeveInspiredDSP
            HardwareStyle.PULTEC -> pultecEQ.process(input)
            HardwareStyle.FAIRCHILD -> fairchildLimiter.process(input)
            HardwareStyle.LA2A -> la2aCompressor.process(input)
            HardwareStyle.UREI1176 -> urei1176.process(input)
            HardwareStyle.MANLEY -> manleyVariMu.process(input)
        }

        // Apply output and mix
        val outputGain = 10f.pow((output - 50f) / 50f * 12f / 20f)
        val wetAmount = mix / 100f

        return FloatArray(input.size) { i ->
            val wet = processed[i] * outputGain
            input[i] * (1f - wetAmount) + wet * wetAmount
        }
    }

    private fun updateParameters() {
        val normalized = character / 100f

        when (currentStyle) {
            HardwareStyle.SSL -> {
                sslCompressor.threshold = -30f + normalized * 25f
                sslCompressor.ratio = 2f + normalized * 8f
            }
            HardwareStyle.API -> {
                apiCompressor.thrust = normalized > 0.5f
                apiCompressor.tone = normalized * 100f
            }
            HardwareStyle.PULTEC -> {
                pultecEQ.lowBoost = normalized * 10f
                pultecEQ.highBoost = normalized * 8f * 0.7f
            }
            HardwareStyle.FAIRCHILD -> {
                fairchildLimiter.inputGain = normalized * 10f
                fairchildLimiter.timeConstant = (normalized * 5).toInt() + 1
            }
            HardwareStyle.LA2A -> {
                la2aCompressor.peakReduction = normalized * 100f
                la2aCompressor.gain = 30f + normalized * 30f
            }
            HardwareStyle.UREI1176 -> {
                urei1176.inputDrive = normalized * 60f
                val ratioIndex = (normalized * 4).toInt().coerceIn(0, 4)
                urei1176.ratio = floatArrayOf(4f, 8f, 12f, 20f, 100f)[ratioIndex]
            }
            HardwareStyle.MANLEY -> {
                manleyVariMu.threshold = -20f + normalized * 15f
                manleyVariMu.compression = normalized * 70f
            }
            HardwareStyle.NEVE -> { /* Handled externally */ }
        }
    }

    fun getGainReduction(): Float = when (currentStyle) {
        HardwareStyle.SSL -> sslCompressor.gainReduction
        HardwareStyle.API -> apiCompressor.gainReduction
        HardwareStyle.FAIRCHILD -> fairchildLimiter.gainReduction
        HardwareStyle.LA2A -> la2aCompressor.gainReduction
        HardwareStyle.UREI1176 -> urei1176.gainReduction
        HardwareStyle.MANLEY -> manleyVariMu.gainReduction
        else -> 0f
    }
}

// MARK: - SSL 4000G Bus Compressor

/**
 * SSL 4000G-style bus compressor
 * Clean, punchy, "glue" compression
 */
class SSLBusCompressor(private val sampleRate: Float = 48000f) {

    var threshold: Float = -15f
    var ratio: Float = 4f
    var attack: Float = 10f
    var release: Float = 300f
    var makeupGain: Float = 0f
    var autoRelease: Boolean = false

    var gainReduction: Float = 0f
        private set

    private var envelope: Float = 0f

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val attackCoeff = exp(-1f / (sampleRate * attack / 1000f))
        val releaseCoeff = exp(-1f / (sampleRate * release / 1000f))
        val makeupLinear = 10f.pow(makeupGain / 20f)

        var maxGR = 0f

        for (i in input.indices) {
            val inputLevel = abs(input[i])

            if (inputLevel > envelope) {
                envelope = attackCoeff * envelope + (1f - attackCoeff) * inputLevel
            } else {
                val relTime = if (autoRelease) calculateAutoRelease(inputLevel) else releaseCoeff
                envelope = relTime * envelope + (1f - relTime) * inputLevel
            }

            val envDB = 20f * log10(maxOf(envelope, 1e-10f))

            var gr = 0f
            if (envDB > threshold) {
                gr = (envDB - threshold) * (1f - 1f / ratio)
            }

            maxGR = minOf(maxGR, -gr)

            val gainLinear = 10f.pow(-gr / 20f) * makeupLinear
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }

    private fun calculateAutoRelease(level: Float): Float {
        val fast = exp(-1f / (sampleRate * 0.1f / 1000f))
        val slow = exp(-1f / (sampleRate * 1.2f / 1000f))
        return if (level > 0.5f) fast else slow
    }
}

// MARK: - API 2500 Bus Compressor

/**
 * API 2500-style compressor with "Thrust" circuit
 */
class APIBusCompressor(private val sampleRate: Float = 48000f) {

    var threshold: Float = -10f
    var ratio: Float = 4f
    var attack: Float = 10f
    var release: Float = 300f
    var thrust: Boolean = true
    var tone: Float = 50f
    var hardKnee: Boolean = true

    var gainReduction: Float = 0f
        private set

    private var envelope: Float = 0f
    private var thrustFilter: Float = 0f

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val attackCoeff = exp(-1f / (sampleRate * attack / 1000f))
        val releaseCoeff = exp(-1f / (sampleRate * release))

        var maxGR = 0f

        for (i in input.indices) {
            var detectSignal = input[i]

            if (thrust) {
                val thrustCoeff = 0.95f
                thrustFilter = thrustCoeff * thrustFilter + (1f - thrustCoeff) * input[i]
                detectSignal = input[i] - thrustFilter
            }

            val inputLevel = abs(detectSignal)

            if (inputLevel > envelope) {
                envelope = attackCoeff * envelope + (1f - attackCoeff) * inputLevel
            } else {
                envelope = releaseCoeff * envelope + (1f - releaseCoeff) * inputLevel
            }

            val envDB = 20f * log10(maxOf(envelope, 1e-10f))

            var gr = 0f
            if (hardKnee) {
                if (envDB > threshold) {
                    gr = (envDB - threshold) * (1f - 1f / ratio)
                }
            } else {
                val knee = 6f
                if (envDB > threshold - knee / 2) {
                    if (envDB < threshold + knee / 2) {
                        val x = envDB - threshold + knee / 2
                        gr = x * x / (2 * knee) * (1f - 1f / ratio)
                    } else {
                        gr = (envDB - threshold) * (1f - 1f / ratio)
                    }
                }
            }

            val toneAmount = tone / 100f
            gr *= (0.7f + toneAmount * 0.6f)

            maxGR = minOf(maxGR, -gr)

            val gainLinear = 10f.pow(-gr / 20f)
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}

// MARK: - Pultec EQP-1A Passive EQ

/**
 * Pultec EQP-1A tube passive EQ emulation
 * Famous "boost and cut" low-end trick
 */
class PultecEQP1A(private val sampleRate: Float = 48000f) {

    var lowFreq: Float = 60f
    var lowBoost: Float = 0f
    var lowAtten: Float = 0f
    var highFreq: Float = 12000f
    var highBoost: Float = 0f
    var highBandwidth: Float = 5f
    var highAtten: Float = 0f
    var tubeOutput: Float = 5f

    private var lowBoostState = floatArrayOf(0f, 0f)
    private var lowAttenState = floatArrayOf(0f, 0f)
    private var highBoostState = floatArrayOf(0f, 0f)
    private var highAttenState = floatArrayOf(0f, 0f)

    fun process(input: FloatArray): FloatArray {
        var output = input.copyOf()

        if (lowBoost > 0.1f) output = applyLowBoost(output)
        if (lowAtten > 0.1f) output = applyLowAtten(output)
        if (highBoost > 0.1f) output = applyHighBoost(output)
        if (highAtten > 0.1f) output = applyHighAtten(output)
        if (tubeOutput > 0.1f) output = applyTubeSaturation(output)

        return output
    }

    private fun applyLowBoost(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val A = 10f.pow(lowBoost * 1.5f / 20f)
        val omega = 2f * PI.toFloat() * lowFreq / sampleRate
        val Q = 0.7f + lowBoost * 0.1f
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)
        val alpha = sinOmega / (2f * Q)
        val sqrtA = sqrt(A)

        val a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
        val b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        val b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega) / a0
        val b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        val a1 = -2 * ((A - 1) + (A + 1) * cosOmega) / a0
        val a2 = ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for (i in input.indices) {
            val x0 = input[i]
            val y0 = b0 * x0 + b1 * lowBoostState[0] + b2 * lowBoostState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            lowBoostState[1] = lowBoostState[0]
            lowBoostState[0] = x0
        }

        return output
    }

    private fun applyLowAtten(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val attenFreq = lowFreq * 1.5f // Pultec trick: cut at different freq
        val A = 10f.pow(-lowAtten * 1f / 20f)
        val omega = 2f * PI.toFloat() * attenFreq / sampleRate
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)
        val alpha = sinOmega / 2f
        val sqrtA = sqrt(A)

        val a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
        val b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        val b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega) / a0
        val b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        val a1 = -2 * ((A - 1) + (A + 1) * cosOmega) / a0
        val a2 = ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for (i in input.indices) {
            val x0 = input[i]
            val y0 = b0 * x0 + b1 * lowAttenState[0] + b2 * lowAttenState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            lowAttenState[1] = lowAttenState[0]
            lowAttenState[0] = x0
        }

        return output
    }

    private fun applyHighBoost(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val A = 10f.pow(highBoost * 1.6f / 20f)
        val omega = 2f * PI.toFloat() * highFreq / sampleRate
        val Q = 0.5f + highBandwidth * 0.3f
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)
        val alpha = sinOmega / (2f * Q)

        val a0 = 1f + alpha / A
        val b0 = (1f + alpha * A) / a0
        val b1 = (-2f * cosOmega) / a0
        val b2 = (1f - alpha * A) / a0
        val a1 = (-2f * cosOmega) / a0
        val a2 = (1f - alpha / A) / a0

        for (i in input.indices) {
            val x0 = input[i]
            val y0 = b0 * x0 + b1 * highBoostState[0] + b2 * highBoostState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            highBoostState[1] = highBoostState[0]
            highBoostState[0] = x0
        }

        return output
    }

    private fun applyHighAtten(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val A = 10f.pow(-highAtten * 1f / 20f)
        val attenFreq = 10000f
        val omega = 2f * PI.toFloat() * attenFreq / sampleRate
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)
        val sqrtA = sqrt(A)
        val alpha = sinOmega / 2f

        val a0 = (A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha
        val b0 = A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        val b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega) / a0
        val b2 = A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        val a1 = 2 * ((A - 1) - (A + 1) * cosOmega) / a0
        val a2 = ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for (i in input.indices) {
            val x0 = input[i]
            val y0 = b0 * x0 + b1 * highAttenState[0] + b2 * highAttenState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            highAttenState[1] = highAttenState[0]
            highAttenState[0] = x0
        }

        return output
    }

    private fun applyTubeSaturation(input: FloatArray): FloatArray {
        val drive = tubeOutput / 10f * 0.5f + 0.5f
        return FloatArray(input.size) { i ->
            val x = input[i] * drive
            val saturated = if (x >= 0) {
                x / (1f + x * 0.3f)
            } else {
                x / (1f - x * 0.2f)
            }
            saturated / (drive * 0.9f)
        }
    }
}

// MARK: - Fairchild 670 Limiter

/**
 * Fairchild 670 tube limiter emulation
 * Variable-mu tube compression with 6 time constants
 */
class FairchildLimiter(private val sampleRate: Float = 48000f) {

    var inputGain: Float = 5f
    var threshold: Float = 10f
    var timeConstant: Int = 3

    var gainReduction: Float = 0f
        private set

    private var envelope: Float = 0f
    private var tubeState: Float = 0f

    private val timeConstants = arrayOf(
        0.2f to 300f,
        0.2f to 800f,
        0.4f to 2000f,
        0.4f to 5000f,
        0.8f to 2000f,
        0.8f to 10000f
    )

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)

        val (attackMs, releaseMs) = timeConstants[minOf(timeConstant - 1, 5)]
        val attackCoeff = exp(-1f / (sampleRate * attackMs / 1000f))
        val releaseCoeff = exp(-1f / (sampleRate * releaseMs / 1000f))

        val inputDriveLinear = 10f.pow(inputGain / 20f)
        val thresholdLinear = 10f.pow(-(10f - threshold) * 2f / 20f)

        var maxGR = 0f

        for (i in input.indices) {
            var driven = input[i] * inputDriveLinear
            driven = tubeSaturation(driven)

            val level = abs(driven)

            if (level > envelope) {
                envelope = attackCoeff * envelope + (1f - attackCoeff) * level
            } else {
                envelope = releaseCoeff * envelope + (1f - releaseCoeff) * level
            }

            var gr = 0f
            if (envelope > thresholdLinear) {
                val excess = envelope / thresholdLinear
                val dynamicRatio = 2f + log10(excess) * 4f
                gr = 20f * log10(excess) * (1f - 1f / dynamicRatio)
            }

            tubeState = tubeState * 0.99f + gr * 0.01f
            gr = tubeState

            maxGR = minOf(maxGR, -gr)

            val gainLinear = 10f.pow(-gr / 20f)
            output[i] = driven * gainLinear / inputDriveLinear
        }

        gainReduction = maxGR
        return output
    }

    private fun tubeSaturation(input: Float): Float {
        val x = input * 1.5f
        return if (abs(x) < 0.5f) {
            x
        } else if (x > 0) {
            0.5f + (x - 0.5f) / (1f + abs(x - 0.5f))
        } else {
            -0.5f + (x + 0.5f) / (1f + abs(x + 0.5f))
        }
    }
}

// MARK: - LA-2A Optical Compressor

/**
 * Teletronix LA-2A optical compressor emulation
 * T4B opto-cell behavior, program-dependent compression
 */
class LA2ACompressor(private val sampleRate: Float = 48000f) {

    var peakReduction: Float = 50f
    var gain: Float = 50f
    var limitMode: Boolean = false

    var gainReduction: Float = 0f
        private set

    private var opticalCell: Float = 0f

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)

        val reductionAmount = peakReduction / 100f
        val outputGain = 10f.pow((gain - 50f) / 50f * 20f / 20f)

        val fastAttack = 0.0001f
        val slowAttack = 0.01f
        val release = 0.06f

        var maxGR = 0f

        for (i in input.indices) {
            val level = abs(input[i])

            if (level > opticalCell) {
                val attackSpeed = if (level > opticalCell * 1.5f) fastAttack else slowAttack
                opticalCell = opticalCell * (1f - attackSpeed) + level * attackSpeed
            } else {
                val releaseSpeed = release / (1f + opticalCell * 5f)
                opticalCell = opticalCell * (1f - releaseSpeed) + level * releaseSpeed
            }

            val threshold = 0.1f + (1f - reductionAmount) * 0.8f
            var gr = 0f

            if (opticalCell > threshold) {
                val excess = opticalCell - threshold
                gr = if (limitMode) excess * 10f else excess * 3f
            }

            maxGR = minOf(maxGR, -gr * 20f)

            val gainLinear = 10f.pow(-gr / 20f) * outputGain
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}

// MARK: - UREI 1176 FET Limiter

/**
 * UREI 1176LN FET limiter emulation
 * Fast, punchy, aggressive compression with FET coloration
 */
class UREI1176Limiter(private val sampleRate: Float = 48000f) {

    var inputDrive: Float = 30f
    var outputLevel: Float = 30f
    var attack: Float = 4f  // 1-7 (inverse: 1 = slow, 7 = fast)
    var release: Float = 4f
    var ratio: Float = 4f  // 4, 8, 12, 20, All (100)

    var gainReduction: Float = 0f
        private set

    private var envelope: Float = 0f

    private val attackTimes = floatArrayOf(0.8f, 0.4f, 0.2f, 0.1f, 0.05f, 0.025f, 0.02f)
    private val releaseTimes = floatArrayOf(1100f, 800f, 500f, 300f, 150f, 80f, 50f)

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)

        val attackIdx = minOf((attack - 1).toInt(), 6)
        val releaseIdx = minOf((release - 1).toInt(), 6)

        val attackMs = attackTimes[attackIdx]
        val releaseMs = releaseTimes[releaseIdx]

        val attackCoeff = exp(-1f / (sampleRate * attackMs / 1000f))
        val releaseCoeff = exp(-1f / (sampleRate * releaseMs / 1000f))

        val inputGain = 10f.pow(inputDrive / 60f * 30f / 20f)
        val outputGain = 10f.pow((outputLevel - 30f) / 60f * 30f / 20f)

        val actualRatio = if (ratio > 20) 100f else ratio

        var maxGR = 0f

        for (i in input.indices) {
            var driven = input[i] * inputGain
            driven = fetColoration(driven)

            val level = abs(driven)

            if (level > envelope) {
                envelope = attackCoeff * envelope + (1f - attackCoeff) * level
            } else {
                envelope = releaseCoeff * envelope + (1f - releaseCoeff) * level
            }

            val threshold = 0.3f
            var gr = 0f

            if (envelope > threshold) {
                val envDB = 20f * log10(envelope / threshold)
                gr = envDB * (1f - 1f / actualRatio)
            }

            gr *= (1f + inputDrive / 100f)

            maxGR = minOf(maxGR, -gr)

            val gainLinear = 10f.pow(-gr / 20f) * outputGain
            output[i] = driven * gainLinear / inputGain
        }

        gainReduction = maxGR
        return output
    }

    private fun fetColoration(input: Float): Float {
        val x = input * 1.2f
        return if (abs(x) < 0.7f) {
            x + x * x * x * 0.05f  // Add 3rd harmonic
        } else if (x > 0) {
            0.7f + (x - 0.7f) * 0.3f
        } else {
            -0.7f + (x + 0.7f) * 0.3f
        }
    }
}

// MARK: - Manley Vari-Mu Compressor

/**
 * Manley Vari-Mu tube compressor emulation
 * Smooth, musical mastering compression
 */
class ManleyVariMu(private val sampleRate: Float = 48000f) {

    var threshold: Float = -10f
    var compression: Float = 50f
    var attack: Float = 25f
    var recovery: Float = 50f
    var outputGain: Float = 0f
    var hpfEnabled: Boolean = true
    var hpfFreq: Float = 100f
    var linked: Boolean = true

    var gainReduction: Float = 0f
        private set

    private var envelope: Float = 0f
    private var hpfState: Float = 0f

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)

        val attackMs = 5f + (attack / 100f) * 65f
        val releaseMs = 200f + (recovery / 100f) * 7800f

        val attackCoeff = exp(-1f / (sampleRate * attackMs / 1000f))
        val releaseCoeff = exp(-1f / (sampleRate * releaseMs / 1000f))

        val thresholdLinear = 10f.pow(threshold / 20f)
        val outputLinear = 10f.pow(outputGain / 20f)
        val compressionAmount = compression / 100f

        var maxGR = 0f

        for (i in input.indices) {
            var detectSignal = input[i]

            if (hpfEnabled) {
                val alpha = exp(-2f * PI.toFloat() * hpfFreq / sampleRate)
                hpfState = alpha * hpfState + (1f - alpha) * input[i]
                detectSignal = input[i] - hpfState
            }

            val level = abs(detectSignal)

            if (level > envelope) {
                envelope = attackCoeff * envelope + (1f - attackCoeff) * level
            } else {
                envelope = releaseCoeff * envelope + (1f - releaseCoeff) * level
            }

            var gr = 0f

            if (envelope > thresholdLinear) {
                val excess = 20f * log10(envelope / thresholdLinear)
                val dynamicRatio = 1.5f + excess * 0.3f * compressionAmount
                gr = excess * (1f - 1f / dynamicRatio) * compressionAmount
            }

            gr = minOf(gr, 20f)

            maxGR = minOf(maxGR, -gr)

            val gainLinear = 10f.pow(-gr / 20f) * outputLinear
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}
