package com.echoelmusic.app.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.Date
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * Immersive Isochronic Engine for Android
 * Professional sound design for focus & relaxation
 *
 * Port of iOS ImmersiveIsochronicEngine with full feature parity:
 * - 6 entrainment presets (deepRest through peakFlow)
 * - 6 soundscapes (warmPad, crystalBowl, organicDrone, etc.)
 * - Bio-reactive modulation (coherence, heart rate)
 * - Breath-sync mode
 * - Session statistics
 *
 * HINWEIS: Isochronic tones may support subjective relaxation and focus.
 * EEG entrainment evidence is mixed. This is a creative/wellness tool, NOT a medical device.
 */
class ImmersiveIsochronicEngine {

    companion object {
        private const val TAG = "IsochronicEngine"
        private const val SAMPLE_RATE = 48000
        private const val BUFFER_SIZE = 1024
    }

    // MARK: - Published State

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying

    private val _currentPreset = MutableStateFlow(EntrainmentPreset.FOCUS)
    val currentPreset: StateFlow<EntrainmentPreset> = _currentPreset

    private val _currentSoundscape = MutableStateFlow(Soundscape.WARM_PAD)
    val currentSoundscape: StateFlow<Soundscape> = _currentSoundscape

    private val _rhythmFrequency = MutableStateFlow(10f)
    val rhythmFrequency: StateFlow<Float> = _rhythmFrequency

    private val _breathSyncEnabled = MutableStateFlow(false)
    val breathSyncEnabled: StateFlow<Boolean> = _breathSyncEnabled

    private val _sessionStats = MutableStateFlow(SessionStatistics())
    val sessionStats: StateFlow<SessionStatistics> = _sessionStats

    // MARK: - Configuration

    var volume: Float = 0.5f
        set(value) { field = value.coerceIn(0f, 1f) }

    var pulseSoftness: Float = 0.7f
        set(value) { field = value.coerceIn(0f, 1f) }

    var bioModulationAmount: Float = 0.5f
    var crossfadeDuration: Float = 2.0f

    // MARK: - Audio Components

    private var audioTrack: AudioTrack? = null
    private var playbackJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Phase accumulators
    private var carrierPhases = mutableListOf<Double>()
    private var pulsePhase = 0.0
    private var lfoPhase = 0.0

    // Session timing
    private var sessionStartTime: Date? = null
    private var currentBreathingRate: Float = 6f

    // MARK: - Entrainment Presets

    enum class EntrainmentPreset(
        val displayName: String,
        val centerFrequency: Float,
        val frequencyRange: ClosedFloatingPointRange<Float>,
        val description: String,
        val recommendedDuration: Int
    ) {
        DEEP_REST(
            "Deep Rest",
            2.5f,
            1.5f..4.0f,
            "Delta band (2-4 Hz) - For winding down before sleep",
            30
        ),
        MEDITATION(
            "Meditation",
            6.0f,
            4.0f..8.0f,
            "Theta band (4-8 Hz) - Reflective, meditative states",
            20
        ),
        RELAXED_FOCUS(
            "Relaxed Focus",
            10.0f,
            8.0f..12.0f,
            "Alpha band (8-12 Hz) - Calm, alert awareness",
            15
        ),
        FOCUS(
            "Focus",
            13.5f,
            12.0f..15.0f,
            "SMR band (12-15 Hz) - Sustained attention, studying",
            25
        ),
        ACTIVE_THINKING(
            "Active Thinking",
            17.5f,
            15.0f..20.0f,
            "Beta band (15-20 Hz) - Active problem-solving",
            20
        ),
        PEAK_FLOW(
            "Peak Flow",
            30.0f,
            20.0f..40.0f,
            "Gamma band (20-40 Hz) - Peak performance moments",
            10
        )
    }

    // MARK: - Soundscapes

    enum class Soundscape(
        val displayName: String,
        val carrierFrequency: Float,
        val harmonics: FloatArray,
        val detuning: FloatArray
    ) {
        WARM_PAD(
            "Warm Pad",
            220f,
            floatArrayOf(1f, 0.5f, 0.25f, 0.125f, 0.06f),
            floatArrayOf(0f, 2f, -2f, 5f, -3f)
        ),
        CRYSTAL_BOWL(
            "Crystal Bowl",
            528f,
            floatArrayOf(1f, 0f, 0.3f, 0f, 0.15f, 0f, 0.08f),
            floatArrayOf(0f, 0f, 1f, 0f, -1f, 0f, 2f)
        ),
        ORGANIC_DRONE(
            "Organic Drone",
            136.1f,
            floatArrayOf(1f, 0.7f, 0.4f, 0.3f, 0.2f, 0.15f, 0.1f, 0.08f),
            floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f)
        ),
        COSMIC_WASH(
            "Cosmic Wash",
            174f,
            floatArrayOf(1f, 0.6f, 0.4f, 0.3f, 0.2f, 0.15f, 0.1f, 0.08f, 0.05f),
            floatArrayOf(0f, 3f, -3f, 5f, -5f, 7f, -7f, 10f, -10f)
        ),
        EARTHY_GROUND(
            "Earthy Ground",
            110f,
            floatArrayOf(1f, 0.8f, 0.4f, 0.2f, 0.1f),
            floatArrayOf(0f, 0f, 1f, -1f, 0f)
        ),
        SHIMMERING_AIR(
            "Shimmering Air",
            396f,
            floatArrayOf(0.3f, 0.5f, 1f, 0.8f, 0.6f, 0.4f, 0.3f, 0.2f),
            floatArrayOf(0f, 1f, 2f, -1f, 3f, -2f, 4f, -3f)
        )
    }

    // MARK: - Session Statistics

    data class SessionStatistics(
        var totalListeningSeconds: Long = 0,
        var sessionsCompleted: Int = 0,
        var presetMinutes: MutableMap<String, Int> = mutableMapOf(),
        var lastSessionDate: Date? = null,
        var currentStreak: Int = 0,
        var longestStreak: Int = 0
    ) {
        val totalMinutes: Int get() = (totalListeningSeconds / 60).toInt()

        val favoritePreset: String?
            get() = presetMinutes.maxByOrNull { it.value }?.key

        fun recordSession(preset: EntrainmentPreset, minutes: Int) {
            val key = preset.name
            presetMinutes[key] = (presetMinutes[key] ?: 0) + minutes
            totalListeningSeconds += minutes * 60L
            sessionsCompleted++

            // Update streak
            val now = Date()
            lastSessionDate?.let { lastDate ->
                val daysSinceLast = ((now.time - lastDate.time) / (1000 * 60 * 60 * 24)).toInt()
                currentStreak = when {
                    daysSinceLast == 1 -> {
                        val newStreak = currentStreak + 1
                        longestStreak = max(longestStreak, newStreak)
                        newStreak
                    }
                    daysSinceLast > 1 -> 1
                    else -> currentStreak
                }
            } ?: run { currentStreak = 1 }
            lastSessionDate = now
        }
    }

    // MARK: - Public API

    fun configure(preset: EntrainmentPreset, soundscape: Soundscape = Soundscape.WARM_PAD) {
        _currentPreset.value = preset
        _currentSoundscape.value = soundscape
        _rhythmFrequency.value = preset.centerFrequency
        updatePhaseArrays()
        Log.i(TAG, "Configured: ${preset.displayName} @ ${rhythmFrequency.value} Hz with ${soundscape.displayName}")
    }

    fun setRhythmFrequency(frequency: Float) {
        _rhythmFrequency.value = frequency.coerceIn(0.5f, 60f)
    }

    fun modulateFromCoherence(coherence: Double) {
        if (bioModulationAmount <= 0) return

        val normalizedCoherence = (coherence / 100.0).coerceIn(0.0, 1.0)
        val baseFrequency = _currentPreset.value.centerFrequency
        val modulationRange = 4f * bioModulationAmount

        val modulatedFreq = baseFrequency + ((normalizedCoherence - 0.5) * modulationRange).toFloat()
        _rhythmFrequency.value = modulatedFreq.coerceIn(2f, 40f)
        Log.i(TAG, "Bio-modulated: coherence ${coherence.toInt()}% → ${rhythmFrequency.value} Hz")
    }

    fun modulateFromHeartRate(bpm: Double) {
        if (bioModulationAmount <= 0) return

        val normalizedHR = ((bpm - 50) / 100).coerceIn(0.0, 1.0)
        pulseSoftness = (0.5f + (1f - normalizedHR.toFloat()) * 0.4f * bioModulationAmount)
    }

    // MARK: - Breath Sync

    fun enableBreathSync(breathingRate: Float = 6f) {
        _breathSyncEnabled.value = true
        currentBreathingRate = breathingRate.coerceIn(2f, 20f)

        val breathHz = currentBreathingRate / 60f
        val entrainmentMultiplier = 60f
        _rhythmFrequency.value = breathHz * entrainmentMultiplier

        Log.i(TAG, "Breath sync enabled: $currentBreathingRate BPM → ${rhythmFrequency.value} Hz")
    }

    fun updateBreathingRate(bpm: Float) {
        if (!_breathSyncEnabled.value) return

        currentBreathingRate = bpm.coerceIn(2f, 20f)
        val breathHz = currentBreathingRate / 60f
        val entrainmentMultiplier = 60f
        _rhythmFrequency.value = breathHz * entrainmentMultiplier
    }

    fun disableBreathSync() {
        _breathSyncEnabled.value = false
        _rhythmFrequency.value = _currentPreset.value.centerFrequency
        Log.i(TAG, "Breath sync disabled, returning to preset frequency")
    }

    // MARK: - Soundscape Transitions

    fun transitionTo(soundscape: Soundscape, duration: Float? = null) {
        _currentSoundscape.value = soundscape
        updatePhaseArrays()
        Log.i(TAG, "Transitioning to ${soundscape.displayName}")
    }

    // MARK: - Lifecycle

    fun start() {
        if (_isPlaying.value) return

        try {
            val bufferSize = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
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
                        .setSampleRate(SAMPLE_RATE)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            audioTrack?.play()
            sessionStartTime = Date()
            _isPlaying.value = true

            // Start audio generation coroutine
            playbackJob = scope.launch {
                generateAudio()
            }

            Log.i(TAG, "Started: ${currentPreset.value.displayName} @ ${rhythmFrequency.value} Hz")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start: ${e.message}")
        }
    }

    fun stop() {
        if (!_isPlaying.value) return

        // Record session statistics
        sessionStartTime?.let { startTime ->
            val sessionDuration = (Date().time - startTime.time) / 1000
            val minutes = (sessionDuration / 60).toInt()
            if (minutes > 0) {
                val stats = _sessionStats.value.copy()
                stats.recordSession(_currentPreset.value, minutes)
                _sessionStats.value = stats
                Log.i(TAG, "Session recorded: $minutes min of ${currentPreset.value.displayName}")
            }
        }
        sessionStartTime = null

        playbackJob?.cancel()
        playbackJob = null

        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null

        // Reset phases
        carrierPhases.clear()
        pulsePhase = 0.0
        lfoPhase = 0.0

        _isPlaying.value = false
        Log.i(TAG, "Stopped")
    }

    val currentSessionDuration: Long
        get() = sessionStartTime?.let { (Date().time - it.time) / 1000 } ?: 0

    fun shutdown() {
        stop()
        scope.cancel()
    }

    // MARK: - Private Methods

    private fun updatePhaseArrays() {
        val harmonicCount = _currentSoundscape.value.harmonics.size
        while (carrierPhases.size < harmonicCount) {
            carrierPhases.add(0.0)
        }
        while (carrierPhases.size > harmonicCount) {
            carrierPhases.removeAt(carrierPhases.lastIndex)
        }
    }

    private suspend fun generateAudio() {
        val buffer = FloatArray(BUFFER_SIZE * 2) // Stereo

        while (isActive && _isPlaying.value) {
            val soundscape = _currentSoundscape.value
            val pulseFreq = _rhythmFrequency.value.toDouble()
            val carrierFreq = soundscape.carrierFrequency.toDouble()
            val harmonics = soundscape.harmonics
            val detuning = soundscape.detuning
            val vol = volume
            val softness = pulseSoftness

            val lfoFreq = 0.1 // Subtle movement

            for (frame in 0 until BUFFER_SIZE) {
                // Pulse Envelope
                val pulseRaw = sin(pulsePhase)
                val pulseEnvelope = if (softness >= 0.9f) {
                    ((pulseRaw + 1.0) / 2.0).toFloat()
                } else {
                    val normalized = (pulseRaw + 1.0) / 2.0
                    val sharpness = 1.0 + (1.0 - softness) * 3.0
                    normalized.pow(sharpness).toFloat()
                }

                // Carrier Tone (Rich Harmonics)
                var sample = 0f
                for ((i, amplitude) in harmonics.withIndex()) {
                    if (amplitude <= 0.01f) continue

                    val harmonicNumber = (i + 1).toDouble()
                    val detuningCents = if (i < detuning.size) detuning[i].toDouble() else 0.0
                    val detuneMultiplier = 2.0.pow(detuningCents / 1200.0)

                    val freq = carrierFreq * harmonicNumber * detuneMultiplier

                    while (carrierPhases.size <= i) {
                        carrierPhases.add(0.0)
                    }

                    sample += amplitude * sin(carrierPhases[i]).toFloat()

                    // Update phase
                    carrierPhases[i] += (2.0 * PI * freq) / SAMPLE_RATE
                    if (carrierPhases[i] > 2.0 * PI) {
                        carrierPhases[i] -= 2.0 * PI
                    }
                }

                // Normalize
                val harmonicSum = harmonics.sum()
                if (harmonicSum > 0) {
                    sample /= harmonicSum
                }

                // Apply pulse envelope
                sample *= pulseEnvelope

                // LFO modulation
                val lfoValue = (sin(lfoPhase) * 0.1 + 1.0).toFloat()
                sample *= lfoValue

                // Apply volume
                sample *= vol

                // Stereo output (slight movement)
                val pan = (sin(lfoPhase * 2.0) * 0.15).toFloat()
                buffer[frame * 2] = sample * (1f - max(pan, 0f))
                buffer[frame * 2 + 1] = sample * (1f + min(pan, 0f))

                // Update phases
                pulsePhase += (2.0 * PI * pulseFreq) / SAMPLE_RATE
                if (pulsePhase > 2.0 * PI) pulsePhase -= 2.0 * PI

                lfoPhase += (2.0 * PI * lfoFreq) / SAMPLE_RATE
                if (lfoPhase > 2.0 * PI) lfoPhase -= 2.0 * PI
            }

            audioTrack?.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING)
            yield() // Allow coroutine cancellation
        }
    }
}
