// SpatialAudioEngine.kt
// Echoelmusic - Android Spatial Audio Implementation
//
// Provides 3D spatial audio positioning and bio-reactive modulation
// Feature parity with iOS SpatialAudioEngine
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

package com.echoelmusic.engines

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

/**
 * Spatial audio mode configuration
 */
enum class SpatialMode(val displayName: String, val channelCount: Int) {
    STEREO("Stereo", 2),
    SURROUND_5_1("5.1 Surround", 6),
    SURROUND_7_1("7.1 Surround", 8),
    SPATIAL_3D("3D Spatial", 2),
    BINAURAL("Binaural", 2),
    AMBISONICS_FOA("First Order Ambisonics", 4),
    AMBISONICS_HOA("Higher Order Ambisonics", 9)
}

/**
 * 3D position in spatial audio field
 */
data class SpatialPosition(
    val x: Float = 0f,  // Left/Right (-1 to 1)
    val y: Float = 0f,  // Up/Down (-1 to 1)
    val z: Float = 0f,  // Front/Back (-1 to 1)
    val distance: Float = 1f  // Distance from listener (0 to infinity)
) {
    /**
     * Calculate azimuth angle in degrees (-180 to 180)
     */
    val azimuth: Float get() = Math.toDegrees(atan2(x.toDouble(), z.toDouble())).toFloat()

    /**
     * Calculate elevation angle in degrees (-90 to 90)
     */
    val elevation: Float get() = Math.toDegrees(asin(y.toDouble() / max(0.001, distance.toDouble()))).toFloat()

    /**
     * Convert to binaural HRTF parameters
     */
    fun toBinauralParams(): BinauralParams {
        val azimuthRad = Math.toRadians(azimuth.toDouble())

        // Interaural Time Difference (ITD) - max ~0.7ms at 90 degrees
        val itd = 0.0007f * sin(azimuthRad).toFloat()

        // Interaural Level Difference (ILD) - frequency dependent, simplified
        val ild = 6f * sin(azimuthRad).toFloat()  // dB difference

        // Distance attenuation (inverse square law)
        val attenuation = 1f / max(1f, distance * distance)

        return BinauralParams(itd, ild, attenuation, azimuth, elevation)
    }

    companion object {
        val CENTER = SpatialPosition(0f, 0f, 1f, 1f)
        val LEFT = SpatialPosition(-1f, 0f, 0f, 1f)
        val RIGHT = SpatialPosition(1f, 0f, 0f, 1f)
        val ABOVE = SpatialPosition(0f, 1f, 0f, 1f)
        val BEHIND = SpatialPosition(0f, 0f, -1f, 1f)
    }
}

/**
 * Binaural audio parameters for HRTF simulation
 */
data class BinauralParams(
    val itd: Float,        // Interaural Time Difference (seconds)
    val ild: Float,        // Interaural Level Difference (dB)
    val attenuation: Float, // Distance attenuation (0-1)
    val azimuth: Float,    // Horizontal angle (degrees)
    val elevation: Float   // Vertical angle (degrees)
)

/**
 * Spatial audio field geometry for multiple sources
 */
sealed class FieldGeometry {
    data class Grid(val rows: Int, val cols: Int, val spacing: Float) : FieldGeometry()
    data class Circle(val count: Int, val radius: Float) : FieldGeometry()
    data class Fibonacci(val count: Int, val radius: Float) : FieldGeometry()
    data class Sphere(val count: Int, val radius: Float) : FieldGeometry()
    data class Custom(val positions: List<SpatialPosition>) : FieldGeometry()

    /**
     * Generate positions for this geometry
     */
    fun generatePositions(): List<SpatialPosition> = when (this) {
        is Grid -> {
            val positions = mutableListOf<SpatialPosition>()
            val halfRows = (rows - 1) / 2f
            val halfCols = (cols - 1) / 2f
            for (r in 0 until rows) {
                for (c in 0 until cols) {
                    val x = (c - halfCols) * spacing
                    val z = (r - halfRows) * spacing
                    positions.add(SpatialPosition(x, 0f, z, sqrt(x * x + z * z)))
                }
            }
            positions
        }
        is Circle -> {
            (0 until count).map { i ->
                val angle = 2 * PI * i / count
                SpatialPosition(
                    x = (radius * sin(angle)).toFloat(),
                    y = 0f,
                    z = (radius * cos(angle)).toFloat(),
                    distance = radius
                )
            }
        }
        is Fibonacci -> {
            // Golden angle distribution for even spacing
            val goldenAngle = PI * (3 - sqrt(5.0))
            (0 until count).map { i ->
                val theta = goldenAngle * i
                val r = radius * sqrt(i.toFloat() / count)
                SpatialPosition(
                    x = (r * cos(theta)).toFloat(),
                    y = 0f,
                    z = (r * sin(theta)).toFloat(),
                    distance = r
                )
            }
        }
        is Sphere -> {
            // Fibonacci sphere distribution
            val goldenRatio = (1 + sqrt(5.0)) / 2
            (0 until count).map { i ->
                val theta = 2 * PI * i / goldenRatio
                val phi = acos(1 - 2 * (i + 0.5) / count)
                SpatialPosition(
                    x = (radius * sin(phi) * cos(theta)).toFloat(),
                    y = (radius * cos(phi)).toFloat(),
                    z = (radius * sin(phi) * sin(theta)).toFloat(),
                    distance = radius
                )
            }
        }
        is Custom -> positions
    }
}

/**
 * Audio voice with spatial properties
 */
data class SpatialVoice(
    val id: Int,
    var position: SpatialPosition = SpatialPosition.CENTER,
    var gain: Float = 1f,
    var muted: Boolean = false,
    var frequency: Float = 440f,
    var waveform: Waveform = Waveform.SINE
) {
    enum class Waveform { SINE, SAW, SQUARE, TRIANGLE, NOISE }
}

/**
 * Spatial Audio Engine for Android
 *
 * Features:
 * - 3D positional audio with binaural HRTF simulation
 * - Multiple spatial modes (stereo, 5.1, 7.1, binaural, ambisonics)
 * - Bio-reactive position modulation
 * - Field geometry generation (grid, circle, Fibonacci, sphere)
 * - Real-time voice management
 */
class SpatialAudioEngine(
    private val context: Context,
    private val sampleRate: Int = 48000
) {
    // State flows
    private val _mode = MutableStateFlow(SpatialMode.BINAURAL)
    val mode: StateFlow<SpatialMode> = _mode.asStateFlow()

    private val _voices = MutableStateFlow<List<SpatialVoice>>(emptyList())
    val voices: StateFlow<List<SpatialVoice>> = _voices.asStateFlow()

    private val _listenerPosition = MutableStateFlow(SpatialPosition.CENTER)
    val listenerPosition: StateFlow<SpatialPosition> = _listenerPosition.asStateFlow()

    private val _listenerOrientation = MutableStateFlow(0f)  // Heading in degrees
    val listenerOrientation: StateFlow<Float> = _listenerOrientation.asStateFlow()

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    // Audio system
    private var audioTrack: AudioTrack? = null
    private var audioJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // HRTF filter coefficients (simplified)
    private val hrtfLeftCoeffs = FloatArray(128) { i ->
        // Simplified left ear impulse response
        val t = i / sampleRate.toFloat()
        exp(-t * 1000) * sin(2 * PI.toFloat() * 1000 * t)
    }

    private val hrtfRightCoeffs = FloatArray(128) { i ->
        // Simplified right ear impulse response
        val t = i / sampleRate.toFloat()
        exp(-t * 1000) * sin(2 * PI.toFloat() * 1100 * t)
    }

    // Delay lines for ITD
    private val leftDelayLine = FloatArray(512)
    private val rightDelayLine = FloatArray(512)
    private var delayWriteIndex = 0

    /**
     * Start the spatial audio engine
     */
    fun start() {
        if (_isRunning.value) return

        val bufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_FLOAT
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize * 4)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()
        _isRunning.value = true

        audioJob = scope.launch {
            val buffer = FloatArray(512 * 2)  // Stereo interleaved
            var phase = 0.0

            while (isActive && _isRunning.value) {
                // Generate and spatialize audio
                for (i in 0 until 512) {
                    var leftSample = 0f
                    var rightSample = 0f

                    // Process each voice
                    for (voice in _voices.value) {
                        if (voice.muted) continue

                        // Generate source sample
                        val sample = voice.gain * when (voice.waveform) {
                            SpatialVoice.Waveform.SINE -> sin(phase * voice.frequency).toFloat()
                            SpatialVoice.Waveform.SAW -> ((phase * voice.frequency % 1.0) * 2 - 1).toFloat()
                            SpatialVoice.Waveform.SQUARE -> if ((phase * voice.frequency % 1.0) < 0.5) 1f else -1f
                            SpatialVoice.Waveform.TRIANGLE -> (abs((phase * voice.frequency % 1.0) * 4 - 2) - 1).toFloat()
                            SpatialVoice.Waveform.NOISE -> (Math.random() * 2 - 1).toFloat()
                        }

                        // Apply spatial processing
                        val binauralParams = voice.position.toBinauralParams()

                        // Apply ILD (level difference)
                        val leftGain = 10f.pow(-binauralParams.ild / 20f)
                        val rightGain = 10f.pow(binauralParams.ild / 20f)

                        // Apply distance attenuation
                        val attenuatedSample = sample * binauralParams.attenuation

                        leftSample += attenuatedSample * leftGain
                        rightSample += attenuatedSample * rightGain
                    }

                    // Clamp to prevent clipping
                    buffer[i * 2] = leftSample.coerceIn(-1f, 1f)
                    buffer[i * 2 + 1] = rightSample.coerceIn(-1f, 1f)

                    phase += 1.0 / sampleRate
                }

                audioTrack?.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING)
            }
        }
    }

    /**
     * Stop the spatial audio engine
     */
    fun stop() {
        _isRunning.value = false
        audioJob?.cancel()
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }

    /**
     * Set the spatial mode
     */
    fun setMode(newMode: SpatialMode) {
        _mode.value = newMode
    }

    /**
     * Add a voice at the specified position
     */
    fun addVoice(position: SpatialPosition = SpatialPosition.CENTER, frequency: Float = 440f): Int {
        val id = (_voices.value.maxOfOrNull { it.id } ?: 0) + 1
        val voice = SpatialVoice(id = id, position = position, frequency = frequency)
        _voices.value = _voices.value + voice
        return id
    }

    /**
     * Remove a voice by ID
     */
    fun removeVoice(id: Int) {
        _voices.value = _voices.value.filter { it.id != id }
    }

    /**
     * Update voice position
     */
    fun setVoicePosition(id: Int, position: SpatialPosition) {
        _voices.value = _voices.value.map {
            if (it.id == id) it.copy(position = position) else it
        }
    }

    /**
     * Set voice gain (0-1)
     */
    fun setVoiceGain(id: Int, gain: Float) {
        _voices.value = _voices.value.map {
            if (it.id == id) it.copy(gain = gain.coerceIn(0f, 1f)) else it
        }
    }

    /**
     * Set voice frequency
     */
    fun setVoiceFrequency(id: Int, frequency: Float) {
        _voices.value = _voices.value.map {
            if (it.id == id) it.copy(frequency = frequency) else it
        }
    }

    /**
     * Mute/unmute a voice
     */
    fun setVoiceMuted(id: Int, muted: Boolean) {
        _voices.value = _voices.value.map {
            if (it.id == id) it.copy(muted = muted) else it
        }
    }

    /**
     * Create voices from a field geometry
     */
    fun createVoicesFromGeometry(geometry: FieldGeometry, baseFrequency: Float = 220f): List<Int> {
        val positions = geometry.generatePositions()
        return positions.mapIndexed { index, position ->
            // Harmonic frequency series
            val frequency = baseFrequency * (index + 1)
            addVoice(position, frequency)
        }
    }

    /**
     * Update listener position (for head tracking)
     */
    fun setListenerPosition(position: SpatialPosition) {
        _listenerPosition.value = position
    }

    /**
     * Update listener orientation (heading in degrees)
     */
    fun setListenerOrientation(headingDegrees: Float) {
        _listenerOrientation.value = headingDegrees
    }

    /**
     * Apply bio-reactive modulation to voice positions
     *
     * @param coherence HRV coherence (0-1), high coherence = stable positions
     * @param heartRate Heart rate in BPM, affects orbital speed
     * @param breathPhase Breathing phase (0-1), affects distance
     */
    fun applyBioModulation(coherence: Float, heartRate: Float = 70f, breathPhase: Float = 0.5f) {
        val orbitalSpeed = heartRate / 60f  // Revolutions per minute to Hz
        val time = System.currentTimeMillis() / 1000.0

        _voices.value = _voices.value.mapIndexed { index, voice ->
            // High coherence = stable, low coherence = chaotic movement
            val chaos = 1f - coherence
            val angle = (time * orbitalSpeed + index * 0.5) * (1 + chaos * 0.5)

            // Breathing affects distance
            val distance = 1f + 0.3f * sin(breathPhase * 2 * PI.toFloat())

            // Update position with bio-reactive modulation
            val newPosition = SpatialPosition(
                x = (distance * sin(angle) * (1 + chaos * 0.2f * sin(time * 3))).toFloat(),
                y = (0.2f * chaos * sin(time * 2 + index)).toFloat(),
                z = (distance * cos(angle) * (1 + chaos * 0.2f * cos(time * 3))).toFloat(),
                distance = distance
            )

            voice.copy(position = newPosition)
        }
    }

    /**
     * Release resources
     */
    fun release() {
        stop()
        scope.cancel()
    }
}
