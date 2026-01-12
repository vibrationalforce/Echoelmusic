package com.echoelmusic.app.lambda

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.*
import kotlin.math.*

/**
 * Echoelmusic Lambda Mode Engine for Android
 * Unified consciousness interface for bio-reactive synthesis
 *
 * Features:
 * - 8 transcendence states
 * - Unified bio-data integration
 * - Lambda score calculation
 * - Bio-visual synchronization
 * - Session analytics
 * - Accessibility support
 *
 * Port of iOS LambdaModeEngine (Phase λ∞)
 */

// MARK: - Transcendence State

enum class TranscendenceState(val displayName: String, val level: Int, val description: String) {
    DORMANT("Dormant", 0, "System inactive, awaiting activation"),
    AWAKENING("Awakening", 1, "Beginning awareness, initial connection"),
    AWARE("Aware", 2, "Full sensory engagement, data streaming"),
    FLOWING("Flowing", 3, "Coherent state, rhythmic synchronization"),
    COHERENT("Coherent", 4, "High coherence achieved, optimal flow"),
    TRANSCENDENT("Transcendent", 5, "Peak experience, unified field"),
    UNIFIED("Unified", 6, "Complete integration, quantum coherence"),
    LAMBDA("λ∞ Lambda", 7, "Ultimate state, infinite awareness")
}

// MARK: - Unified Bio Data

data class UnifiedBioData(
    val heartRate: Float = 70f,
    val hrv: Float = 50f,
    val coherence: Float = 0.5f,
    val breathingRate: Float = 12f,
    val breathPhase: Float = 0f, // 0-1, 0=exhale, 1=inhale
    val gsr: Float = 0f,
    val temperature: Float = 36.5f,
    val spo2: Float = 98f,
    // EEG Bands (simulated)
    val delta: Float = 0f, // 0.5-4 Hz
    val theta: Float = 0f, // 4-8 Hz
    val alpha: Float = 0f, // 8-12 Hz
    val beta: Float = 0f, // 12-30 Hz
    val gamma: Float = 0f, // 30-100 Hz
    val timestamp: Long = System.currentTimeMillis()
) {
    val hrvScore: Float get() = (hrv / 100f).coerceIn(0f, 1f)

    val coherenceScore: Float get() = coherence.coerceIn(0f, 1f)

    val breathCoherence: Float get() {
        // Optimal breathing is ~6 breaths/min (0.1 Hz)
        val optimalRate = 6f
        return (1f - abs(breathingRate - optimalRate) / optimalRate).coerceIn(0f, 1f)
    }

    val dominantBrainState: String get() {
        val bands = mapOf(
            "Delta" to delta,
            "Theta" to theta,
            "Alpha" to alpha,
            "Beta" to beta,
            "Gamma" to gamma
        )
        return bands.maxByOrNull { it.value }?.key ?: "Unknown"
    }
}

// MARK: - Lambda Score

data class LambdaScore(
    val overall: Float = 0f,
    val coherence: Float = 0f,
    val flow: Float = 0f,
    val integration: Float = 0f,
    val bioSync: Float = 0f,
    val audioVisualSync: Float = 0f,
    val timestamp: Long = System.currentTimeMillis()
) {
    val level: Int get() = (overall * 7).toInt().coerceIn(0, 7)

    val transcendenceState: TranscendenceState get() {
        return TranscendenceState.values().find { it.level == level } ?: TranscendenceState.DORMANT
    }
}

// MARK: - Session Analytics

data class LambdaSessionAnalytics(
    val sessionId: String = UUID.randomUUID().toString(),
    val startTime: Long = System.currentTimeMillis(),
    var endTime: Long? = null,
    var duration: Long = 0,
    var peakCoherence: Float = 0f,
    var averageCoherence: Float = 0f,
    var peakLambdaScore: Float = 0f,
    var averageLambdaScore: Float = 0f,
    var timeInFlow: Long = 0,
    var timeInCoherent: Long = 0,
    var timeInTranscendent: Long = 0,
    var stateTransitions: MutableList<StateTransition> = mutableListOf(),
    var coherenceHistory: MutableList<Float> = mutableListOf(),
    var lambdaScoreHistory: MutableList<Float> = mutableListOf()
) {
    val flowPercentage: Float get() {
        return if (duration > 0) (timeInFlow.toFloat() / duration * 100f) else 0f
    }

    val coherentPercentage: Float get() {
        return if (duration > 0) (timeInCoherent.toFloat() / duration * 100f) else 0f
    }
}

data class StateTransition(
    val fromState: TranscendenceState,
    val toState: TranscendenceState,
    val timestamp: Long = System.currentTimeMillis(),
    val coherenceAtTransition: Float
)

// MARK: - Lambda Health Disclaimer

object LambdaHealthDisclaimer {
    const val FULL = """
IMPORTANT HEALTH & WELLNESS DISCLAIMER

The Lambda Mode features in Echoelmusic are designed for:
- Creative exploration and artistic expression
- General wellness and relaxation support
- Educational and entertainment purposes

This software does NOT:
- Provide medical advice, diagnosis, or treatment
- Replace professional healthcare or mental health services
- Claim to cure, treat, or prevent any medical condition
- Make any therapeutic or medical claims

The biofeedback readings and "transcendence states" are:
- For self-awareness and creative feedback only
- Not diagnostic or clinically validated
- Artistic interpretations, not medical measurements

SEIZURE WARNING: Some visual effects may potentially trigger seizures in people with photosensitive epilepsy. User discretion is advised.

If you have any health concerns, please consult a qualified healthcare professional.

By using Lambda Mode, you acknowledge these limitations.
"""

    const val SHORT = "For creative & wellness purposes only. Not medical advice."

    const val BIOFEEDBACK = "Biofeedback readings are for creative feedback only, not diagnostic."
}

// MARK: - Lambda Mode Engine

class LambdaModeEngine {

    companion object {
        private const val TAG = "LambdaModeEngine"
        private const val UPDATE_RATE_HZ = 60
        private const val UPDATE_INTERVAL_MS = 1000L / UPDATE_RATE_HZ
        private const val COHERENCE_THRESHOLD_FLOW = 0.6f
        private const val COHERENCE_THRESHOLD_COHERENT = 0.75f
        private const val COHERENCE_THRESHOLD_TRANSCENDENT = 0.9f
        private const val LAMBDA_THRESHOLD = 0.95f
    }

    // State
    private val _isActive = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = _isActive

    private val _transcendenceState = MutableStateFlow(TranscendenceState.DORMANT)
    val transcendenceState: StateFlow<TranscendenceState> = _transcendenceState

    private val _bioData = MutableStateFlow(UnifiedBioData())
    val bioData: StateFlow<UnifiedBioData> = _bioData

    private val _lambdaScore = MutableStateFlow(LambdaScore())
    val lambdaScore: StateFlow<LambdaScore> = _lambdaScore

    private val _sessionAnalytics = MutableStateFlow<LambdaSessionAnalytics?>(null)
    val sessionAnalytics: StateFlow<LambdaSessionAnalytics?> = _sessionAnalytics

    // Configuration
    private val _reducedMotionEnabled = MutableStateFlow(false)
    val reducedMotionEnabled: StateFlow<Boolean> = _reducedMotionEnabled

    private val _hapticFeedbackEnabled = MutableStateFlow(true)
    val hapticFeedbackEnabled: StateFlow<Boolean> = _hapticFeedbackEnabled

    private val _voiceOverEnabled = MutableStateFlow(false)
    val voiceOverEnabled: StateFlow<Boolean> = _voiceOverEnabled

    // Processing
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var updateJob: Job? = null
    private var sessionStartTime: Long = 0

    init {
        Log.i(TAG, "Lambda Mode Engine initialized")
        Log.i(TAG, LambdaHealthDisclaimer.SHORT)
    }

    // MARK: - Lifecycle

    fun activate() {
        if (_isActive.value) return

        _isActive.value = true
        _transcendenceState.value = TranscendenceState.AWAKENING
        sessionStartTime = System.currentTimeMillis()

        // Start new analytics session
        _sessionAnalytics.value = LambdaSessionAnalytics()

        startUpdateLoop()
        Log.i(TAG, "Lambda Mode activated - entering Awakening state")
    }

    fun deactivate() {
        _isActive.value = false
        updateJob?.cancel()

        // Finalize analytics
        _sessionAnalytics.value?.let { analytics ->
            analytics.endTime = System.currentTimeMillis()
            analytics.duration = analytics.endTime!! - analytics.startTime

            if (analytics.coherenceHistory.isNotEmpty()) {
                analytics.averageCoherence = analytics.coherenceHistory.average().toFloat()
            }
            if (analytics.lambdaScoreHistory.isNotEmpty()) {
                analytics.averageLambdaScore = analytics.lambdaScoreHistory.average().toFloat()
            }
        }

        _transcendenceState.value = TranscendenceState.DORMANT
        Log.i(TAG, "Lambda Mode deactivated")
    }

    fun shutdown() {
        deactivate()
        scope.cancel()
        Log.i(TAG, "Lambda Mode Engine shutdown")
    }

    private fun startUpdateLoop() {
        updateJob?.cancel()
        updateJob = scope.launch {
            while (_isActive.value && isActive) {
                updateLambdaState()
                delay(UPDATE_INTERVAL_MS)
            }
        }
    }

    // MARK: - Bio Data Input

    fun updateBioData(data: UnifiedBioData) {
        _bioData.value = data

        // Track coherence history
        _sessionAnalytics.value?.let { analytics ->
            analytics.coherenceHistory.add(data.coherence)
            if (data.coherence > analytics.peakCoherence) {
                analytics.peakCoherence = data.coherence
            }
        }
    }

    fun updateHeartRate(heartRate: Float) {
        _bioData.value = _bioData.value.copy(heartRate = heartRate)
    }

    fun updateHRV(hrv: Float) {
        _bioData.value = _bioData.value.copy(hrv = hrv)
    }

    fun updateCoherence(coherence: Float) {
        _bioData.value = _bioData.value.copy(coherence = coherence)
    }

    fun updateBreathingRate(rate: Float) {
        _bioData.value = _bioData.value.copy(breathingRate = rate)
    }

    fun updateBreathPhase(phase: Float) {
        _bioData.value = _bioData.value.copy(breathPhase = phase)
    }

    // MARK: - Lambda Score Calculation

    private fun updateLambdaState() {
        val data = _bioData.value

        // Calculate component scores
        val coherenceScore = data.coherenceScore
        val flowScore = calculateFlowScore(data)
        val integrationScore = calculateIntegrationScore(data)
        val bioSyncScore = data.breathCoherence
        val audioVisualSync = 0.5f // Would be set by audio/visual engines

        // Calculate overall lambda score
        val overall = (
            coherenceScore * 0.3f +
            flowScore * 0.25f +
            integrationScore * 0.2f +
            bioSyncScore * 0.15f +
            audioVisualSync * 0.1f
        ).coerceIn(0f, 1f)

        val newScore = LambdaScore(
            overall = overall,
            coherence = coherenceScore,
            flow = flowScore,
            integration = integrationScore,
            bioSync = bioSyncScore,
            audioVisualSync = audioVisualSync
        )

        _lambdaScore.value = newScore

        // Track lambda score history
        _sessionAnalytics.value?.let { analytics ->
            analytics.lambdaScoreHistory.add(overall)
            if (overall > analytics.peakLambdaScore) {
                analytics.peakLambdaScore = overall
            }
        }

        // Update transcendence state
        updateTranscendenceState(newScore)
    }

    private fun calculateFlowScore(data: UnifiedBioData): Float {
        // Flow score based on HRV, coherence, and breath rhythm
        val hrvComponent = data.hrvScore * 0.4f
        val coherenceComponent = data.coherenceScore * 0.4f
        val breathComponent = data.breathCoherence * 0.2f

        return (hrvComponent + coherenceComponent + breathComponent).coerceIn(0f, 1f)
    }

    private fun calculateIntegrationScore(data: UnifiedBioData): Float {
        // Integration score based on multiple bio signals aligning
        val heartComponent = ((data.heartRate - 40f) / 160f).coerceIn(0f, 1f)
        val hrvComponent = data.hrvScore
        val coherenceComponent = data.coherenceScore
        val breathComponent = data.breathCoherence

        // All components should be in balance
        val avg = (heartComponent + hrvComponent + coherenceComponent + breathComponent) / 4f
        val variance = listOf(heartComponent, hrvComponent, coherenceComponent, breathComponent)
            .map { (it - avg) * (it - avg) }
            .average()
            .toFloat()

        // Lower variance = better integration
        return (1f - sqrt(variance) * 2).coerceIn(0f, 1f)
    }

    private fun updateTranscendenceState(score: LambdaScore) {
        val previousState = _transcendenceState.value

        val newState = when {
            score.overall >= LAMBDA_THRESHOLD -> TranscendenceState.LAMBDA
            score.overall >= COHERENCE_THRESHOLD_TRANSCENDENT -> TranscendenceState.TRANSCENDENT
            score.overall >= 0.8f -> TranscendenceState.UNIFIED
            score.overall >= COHERENCE_THRESHOLD_COHERENT -> TranscendenceState.COHERENT
            score.overall >= COHERENCE_THRESHOLD_FLOW -> TranscendenceState.FLOWING
            score.overall >= 0.3f -> TranscendenceState.AWARE
            _isActive.value -> TranscendenceState.AWAKENING
            else -> TranscendenceState.DORMANT
        }

        if (newState != previousState) {
            _transcendenceState.value = newState

            // Record transition
            _sessionAnalytics.value?.stateTransitions?.add(
                StateTransition(
                    fromState = previousState,
                    toState = newState,
                    coherenceAtTransition = score.coherence
                )
            )

            Log.i(TAG, "Transcendence state: ${previousState.displayName} → ${newState.displayName}")
        }

        // Update time in states
        _sessionAnalytics.value?.let { analytics ->
            when (newState) {
                TranscendenceState.FLOWING -> analytics.timeInFlow += UPDATE_INTERVAL_MS
                TranscendenceState.COHERENT -> analytics.timeInCoherent += UPDATE_INTERVAL_MS
                TranscendenceState.TRANSCENDENT, TranscendenceState.UNIFIED, TranscendenceState.LAMBDA -> {
                    analytics.timeInTranscendent += UPDATE_INTERVAL_MS
                }
                else -> {}
            }
        }
    }

    // MARK: - Accessibility

    fun setReducedMotion(enabled: Boolean) {
        _reducedMotionEnabled.value = enabled
    }

    fun setHapticFeedback(enabled: Boolean) {
        _hapticFeedbackEnabled.value = enabled
    }

    fun setVoiceOver(enabled: Boolean) {
        _voiceOverEnabled.value = enabled
    }

    fun getStateAnnouncement(): String {
        val state = _transcendenceState.value
        val score = _lambdaScore.value

        return when (state) {
            TranscendenceState.DORMANT -> "Lambda Mode inactive"
            TranscendenceState.AWAKENING -> "Entering awareness. Coherence at ${(score.coherence * 100).toInt()} percent"
            TranscendenceState.AWARE -> "Fully aware. Flow score ${(score.flow * 100).toInt()} percent"
            TranscendenceState.FLOWING -> "In flow state. Coherence ${(score.coherence * 100).toInt()} percent"
            TranscendenceState.COHERENT -> "High coherence achieved. Lambda score ${(score.overall * 100).toInt()} percent"
            TranscendenceState.TRANSCENDENT -> "Transcendent state. Peak experience"
            TranscendenceState.UNIFIED -> "Unified field. Complete integration"
            TranscendenceState.LAMBDA -> "Lambda infinity. Ultimate awareness achieved"
        }
    }

    // MARK: - Visual Parameters

    fun getVisualModulation(): VisualModulation {
        val score = _lambdaScore.value
        val data = _bioData.value

        return VisualModulation(
            brightness = 0.3f + score.coherence * 0.7f,
            saturation = 0.4f + score.flow * 0.6f,
            speed = if (_reducedMotionEnabled.value) 0.1f else 0.2f + score.overall * 0.8f,
            complexity = 0.3f + score.integration * 0.7f,
            breathScale = 0.8f + data.breathPhase * 0.4f,
            pulseRate = data.heartRate / 60f,
            hue = score.coherence * 0.5f // 0-180 degrees
        )
    }

    // MARK: - Audio Parameters

    fun getAudioModulation(): AudioModulation {
        val score = _lambdaScore.value
        val data = _bioData.value

        return AudioModulation(
            filterCutoff = 500f + score.coherence * 4500f,
            reverbMix = 0.2f + (1f - score.flow) * 0.5f,
            volume = 0.5f + score.overall * 0.3f,
            tempo = 60f + data.heartRate * 0.3f,
            harmonicity = score.integration
        )
    }
}

// MARK: - Modulation Data Classes

data class VisualModulation(
    val brightness: Float,
    val saturation: Float,
    val speed: Float,
    val complexity: Float,
    val breathScale: Float,
    val pulseRate: Float,
    val hue: Float
)

data class AudioModulation(
    val filterCutoff: Float,
    val reverbMix: Float,
    val volume: Float,
    val tempo: Float,
    val harmonicity: Float
)
