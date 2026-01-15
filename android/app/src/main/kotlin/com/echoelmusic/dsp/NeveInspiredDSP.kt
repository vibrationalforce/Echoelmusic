package com.echoelmusic.dsp

import kotlin.math.*

/**
 * Neve-Inspired Mastering DSP Processors for Android
 * Cross-Platform Support: Android 8+ (API 26+)
 * iOS/Swift equivalent: Sources/Echoelmusic/DSP/NeveInspiredDSP.swift
 *
 * Inspired by:
 * - Neve 33609 Compressor/Limiter
 * - Neve 1073/1084 Preamp & EQ
 * - Neve MBT (Master Bus Transformer)
 * - Neve Silk Circuit
 */

// MARK: - Neve Transformer Saturation (MBT-inspired)

/**
 * Neve MBT-style transformer saturation
 * Adds warmth and harmonic richness through transformer modeling
 */
class NeveTransformerSaturation(private val sampleRate: Float = 48000f) {

    enum class SilkMode { RED, BLUE }

    var drive: Float = 30f           // 0-100 (transformer drive)
    var texture: Float = 50f         // 0-100 (harmonic texture)
    var silk: Float = 50f            // 0-100 (high-frequency smoothing)
    var silkMode: SilkMode = SilkMode.RED  // RED = 8kHz, BLUE = 12kHz

    private var hysteresisState: Float = 0f

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val driveAmount = drive / 100f
        val textureAmount = texture / 100f

        for (i in input.indices) {
            var sample = input[i]

            // Input transformer saturation
            sample *= (1f + driveAmount * 2f)

            // Even harmonic generation (transformer characteristic)
            sample = addEvenHarmonics(sample, driveAmount * textureAmount)

            // Transformer hysteresis (magnetic core behavior)
            sample = applyHysteresis(sample, driveAmount * 0.3f)

            // Silk circuit (HF smoothing)
            if (silk > 0) {
                sample = applySilkCircuit(sample)
            }

            // Output transformer coloration
            sample = outputTransformerColor(sample)

            output[i] = sample
        }

        return output
    }

    private fun addEvenHarmonics(input: Float, amount: Float): Float {
        val second = input * input * 0.5f
        val fourth = input * input * input * input * 0.125f
        return input + (second + fourth) * amount * 0.3f
    }

    private fun applyHysteresis(input: Float, amount: Float): Float {
        val targetState = tanh(input * (1f + amount))
        hysteresisState = hysteresisState * 0.9f + targetState * 0.1f
        return hysteresisState
    }

    private fun applySilkCircuit(input: Float): Float {
        val silkAmount = silk / 100f
        return input * (1f - silkAmount * 0.1f)
    }

    private fun outputTransformerColor(input: Float): Float {
        return input / (1f + abs(input) * 0.05f)
    }
}

// MARK: - Neve Inductor EQ (1073-inspired)

/**
 * Neve 1073-style inductor EQ
 * Musical, proportional-Q behavior with inductor resonance
 */
class NeveInductorEQ(private val sampleRate: Float = 48000f) {

    var lowFreq: Float = 110f        // Hz (35, 60, 110, 220)
    var lowGain: Float = 0f          // dB (-16 to +16)
    var midFreq: Float = 1600f       // Hz (360, 700, 1600, 3200, 4800, 7200)
    var midGain: Float = 0f          // dB
    var highFreq: Float = 12000f     // Hz (fixed shelf)
    var highGain: Float = 0f         // dB

    private var lowState = floatArrayOf(0f, 0f)
    private var midState = floatArrayOf(0f, 0f)
    private var highState = floatArrayOf(0f, 0f)

    fun process(input: FloatArray): FloatArray {
        var output = input.copyOf()

        if (abs(lowGain) > 0.1f) {
            output = applyLowShelf(output)
        }
        if (abs(midGain) > 0.1f) {
            output = applyMidBell(output)
        }
        if (abs(highGain) > 0.1f) {
            output = applyHighShelf(output)
        }

        return output
    }

    private fun applyLowShelf(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val A = 10f.pow(lowGain / 40f)
        val omega = 2f * PI.toFloat() * lowFreq / sampleRate
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)
        val Q = 0.7f + abs(lowGain) * 0.02f
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
            val y0 = b0 * x0 + b1 * lowState[0] + b2 * lowState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            lowState[1] = lowState[0]
            lowState[0] = x0
        }

        return output
    }

    private fun applyMidBell(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val A = 10f.pow(midGain / 40f)
        val omega = 2f * PI.toFloat() * midFreq / sampleRate
        val sinOmega = sin(omega)
        val cosOmega = cos(omega)
        val Q = 2.5f
        val alpha = sinOmega / (2f * Q)

        val a0 = 1f + alpha / A
        val b0 = (1f + alpha * A) / a0
        val b1 = (-2f * cosOmega) / a0
        val b2 = (1f - alpha * A) / a0
        val a1 = (-2f * cosOmega) / a0
        val a2 = (1f - alpha / A) / a0

        for (i in input.indices) {
            val x0 = input[i]
            val y0 = b0 * x0 + b1 * midState[0] + b2 * midState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            midState[1] = midState[0]
            midState[0] = x0
        }

        return output
    }

    private fun applyHighShelf(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)
        val A = 10f.pow(highGain / 40f)
        val omega = 2f * PI.toFloat() * highFreq / sampleRate
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
            val y0 = b0 * x0 + b1 * highState[0] + b2 * highState[1] -
                    a1 * (if (i > 0) output[i - 1] else 0f) -
                    a2 * (if (i > 1) output[i - 2] else 0f)
            output[i] = y0
            highState[1] = highState[0]
            highState[0] = x0
        }

        return output
    }
}

// MARK: - Neve Feedback Compressor (33609-inspired)

/**
 * Neve 33609-style feedback compressor
 * Classic British compression with feedback topology
 */
class NeveFeedbackCompressor(private val sampleRate: Float = 48000f) {

    var threshold: Float = -10f      // dB
    var ratio: Float = 2f            // 1.5, 2, 3, 4, 6
    var attack: Float = 1f           // 1-6 (fast to slow)
    var recovery: Float = 3f         // 1-6 (fast to slow)
    var makeupGain: Float = 0f       // dB
    var limiterEnabled: Boolean = false

    var gainReduction: Float = 0f
        private set

    private var envelope: Float = 0f

    private val attackTimes = floatArrayOf(0.2f, 0.5f, 1f, 2f, 5f, 10f)
    private val releaseTimes = floatArrayOf(100f, 200f, 400f, 800f, 1500f, 3000f)

    fun process(input: FloatArray): FloatArray {
        val output = FloatArray(input.size)

        val attackIdx = minOf((attack - 1).toInt(), 5)
        val releaseIdx = minOf((recovery - 1).toInt(), 5)

        val attackMs = attackTimes[attackIdx]
        val releaseMs = releaseTimes[releaseIdx]

        val attackCoeff = exp(-1f / (sampleRate * attackMs / 1000f))
        val releaseCoeff = exp(-1f / (sampleRate * releaseMs / 1000f))

        val thresholdLinear = 10f.pow(threshold / 20f)
        val makeupLinear = 10f.pow(makeupGain / 20f)

        var maxGR = 0f

        for (i in input.indices) {
            // Feedback topology - detect AFTER gain reduction
            val outputEstimate = input[i] * 10f.pow(-gainReduction / 20f)
            val detectedLevel = abs(outputEstimate)

            // Envelope follower
            if (detectedLevel > envelope) {
                envelope = attackCoeff * envelope + (1f - attackCoeff) * detectedLevel
            } else {
                envelope = releaseCoeff * envelope + (1f - releaseCoeff) * detectedLevel
            }

            // Calculate gain reduction
            var gr = 0f
            if (envelope > thresholdLinear) {
                val envDB = 20f * log10(envelope / thresholdLinear)
                gr = envDB * (1f - 1f / ratio)
            }

            // Limiter
            if (limiterEnabled) {
                gr = maxOf(gr, 0f)
            }

            maxGR = minOf(maxGR, -gr)

            // Apply gain
            val gainLinear = 10f.pow(-gr / 20f) * makeupLinear
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}

// MARK: - Neve Mastering Chain

/**
 * Complete Neve-inspired mastering signal chain
 */
class NeveMasteringChain(private val sampleRate: Float = 48000f) {

    val inputTransformer = NeveTransformerSaturation(sampleRate)
    val eq = NeveInductorEQ(sampleRate)
    val compressor = NeveFeedbackCompressor(sampleRate)
    val outputTransformer = NeveTransformerSaturation(sampleRate)

    var bypassed: Boolean = false

    fun process(input: FloatArray): FloatArray {
        if (bypassed) return input

        var output = input
        output = inputTransformer.process(output)
        output = eq.process(output)
        output = compressor.process(output)
        output = outputTransformer.process(output)

        return output
    }

    fun applyWarmPreset() {
        inputTransformer.drive = 40f
        inputTransformer.silk = 60f
        eq.lowGain = 2f
        eq.highGain = -1f
        compressor.ratio = 2f
        compressor.threshold = -8f
    }

    fun applyTransparentPreset() {
        inputTransformer.drive = 20f
        inputTransformer.silk = 30f
        eq.lowGain = 0f
        eq.midGain = 0f
        eq.highGain = 0f
        compressor.ratio = 1.5f
        compressor.threshold = -6f
    }

    fun applyPunchyPreset() {
        inputTransformer.drive = 50f
        inputTransformer.silk = 40f
        eq.lowGain = 3f
        eq.midGain = 1f
        eq.highGain = 2f
        compressor.ratio = 4f
        compressor.threshold = -12f
        compressor.attack = 1f
    }
}
