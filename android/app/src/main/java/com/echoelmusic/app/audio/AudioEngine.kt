package com.echoelmusic.app.audio

import android.content.Context
import android.media.AudioManager
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Echoelmusic Audio Engine
 * Wraps native Oboe-based audio engine for ultra-low-latency synthesis
 *
 * Features:
 * - AAudio (Android 8.0+) / OpenSL ES fallback
 * - < 10ms latency on supported devices
 * - 16-voice polyphonic synth
 * - EchoelBeat Bass with pitch glide
 * - Bio-reactive parameter modulation
 */
class AudioEngine(private val context: Context) {

    companion object {
        private const val TAG = "AudioEngine"
    }

    // State
    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private val _latencyMs = MutableStateFlow(0f)
    val latencyMs: StateFlow<Float> = _latencyMs

    var isServiceRunning = false
        private set

    // Audio configuration
    private var sampleRate = 48000
    private var framesPerBuffer = 192 // ~4ms at 48kHz

    init {
        // Get optimal audio settings from system
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.let {
            sampleRate = it.toIntOrNull() ?: 48000
        }

        audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.let {
            framesPerBuffer = it.toIntOrNull() ?: 192
        }

        Log.i(TAG, "Audio config: $sampleRate Hz, $framesPerBuffer frames/buffer")
        Log.i(TAG, "Target latency: ${framesPerBuffer * 1000f / sampleRate} ms")

        // Initialize native engine
        nativeCreate(sampleRate, framesPerBuffer)
    }

    fun start() {
        if (_isRunning.value) return

        val success = nativeStart()
        if (success) {
            _isRunning.value = true
            _latencyMs.value = nativeGetLatencyMs()
            Log.i(TAG, "Audio started. Latency: ${_latencyMs.value} ms")
        } else {
            Log.e(TAG, "Failed to start audio")
        }
    }

    fun stop() {
        if (!_isRunning.value) return

        nativeStop()
        _isRunning.value = false
        Log.i(TAG, "Audio stopped")
    }

    fun shutdown() {
        stop()
        nativeDestroy()
    }

    // Synth controls
    fun noteOn(note: Int, velocity: Int) {
        nativeNoteOn(note, velocity)
    }

    fun noteOff(note: Int) {
        nativeNoteOff(note)
    }

    fun setParameter(paramId: Int, value: Float) {
        nativeSetParameter(paramId, value)
    }

    // Bio-reactive modulation
    fun updateBioData(heartRate: Float, hrv: Float, coherence: Float) {
        nativeUpdateBioData(heartRate, hrv, coherence)
    }

    // EchoelBeat Bass
    fun trigger808(note: Int, velocity: Int) {
        nativeTrigger808(note, velocity)
    }

    fun set808Parameter(paramId: Int, value: Float) {
        nativeSet808Parameter(paramId, value)
    }

    // Parameter IDs
    object Params {
        // Oscillator
        const val OSC1_WAVEFORM = 0
        const val OSC1_OCTAVE = 1
        const val OSC2_WAVEFORM = 2
        const val OSC2_MIX = 3

        // Filter
        const val FILTER_CUTOFF = 10
        const val FILTER_RESONANCE = 11
        const val FILTER_ENV_AMOUNT = 12

        // Envelopes
        const val AMP_ATTACK = 20
        const val AMP_DECAY = 21
        const val AMP_SUSTAIN = 22
        const val AMP_RELEASE = 23

        // LFO
        const val LFO_RATE = 30
        const val LFO_DEPTH = 31
        const val LFO_TO_FILTER = 32

        // 808 Bass
        const val BASS_DECAY = 40
        const val BASS_TONE = 41
        const val BASS_DRIVE = 42
        const val BASS_GLIDE_TIME = 43
        const val BASS_GLIDE_RANGE = 44
    }

    // Native methods - implemented in C++
    private external fun nativeCreate(sampleRate: Int, framesPerBuffer: Int): Boolean
    private external fun nativeStart(): Boolean
    private external fun nativeStop()
    private external fun nativeDestroy()
    private external fun nativeGetLatencyMs(): Float

    private external fun nativeNoteOn(note: Int, velocity: Int)
    private external fun nativeNoteOff(note: Int)
    private external fun nativeSetParameter(paramId: Int, value: Float)

    private external fun nativeUpdateBioData(heartRate: Float, hrv: Float, coherence: Float)

    private external fun nativeTrigger808(note: Int, velocity: Int)
    private external fun nativeSet808Parameter(paramId: Int, value: Float)
}
