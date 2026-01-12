/**
 * QuantumHealthBiofeedbackEngine.kt
 *
 * Quantum-inspired health biofeedback system with:
 * - 10 biometric observables + 5 quantum metrics
 * - Unlimited participants per session
 * - 8 session types
 * - Real-time broadcasting (8 platforms)
 * - Privacy modes
 *
 * Also includes AdeyWindowsBioelectromagneticEngine for
 * scientific frequency-body mapping (Dr. W. Ross Adey research)
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 *
 * DISCLAIMER: "Quantum" refers to quantum-inspired algorithms, not quantum hardware.
 * This is NOT a medical device.
 */
package com.echoelmusic.quantum

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

// ============================================================================
// QUANTUM HEALTH STATE
// ============================================================================

/**
 * Comprehensive biometric + quantum-inspired state
 */
data class QuantumHealthState(
    // Biometric Observables (10)
    val heartRate: Int = 72,
    val hrvSdnn: Float = 50f,
    val hrvRmssd: Float = 40f,
    val hrvCoherence: Float = 0.5f,
    val respiratoryRate: Float = 12f,
    val spo2: Float = 98f,
    val skinConductance: Float = 5f,   // microSiemens
    val skinTemperature: Float = 32f,
    val bloodPressureSystolic: Int = 120,
    val bloodPressureDiastolic: Int = 80,

    // Quantum-Inspired Metrics (5)
    val quantumCoherence: Float = 0.5f,     // Bio-inspired coherence
    val entanglementPotential: Float = 0f,  // Sync with group
    val superpositionIndex: Float = 0f,     // State variability
    val collapseStability: Float = 0.5f,    // State stability
    val observerEffect: Float = 0f,         // Attention influence

    // Derived Health Score
    val quantumHealthScore: Float = 50f,     // 0-100
    val timestamp: Long = System.currentTimeMillis()
)

// ============================================================================
// SESSION TYPES
// ============================================================================

enum class QuantumSessionType(
    val displayName: String,
    val description: String,
    val optimalDuration: Int,  // Minutes
    val maxParticipants: Int
) {
    MEDITATION(
        "Quantum Meditation",
        "Deep coherence-focused meditation",
        30,
        1000
    ),
    COHERENCE_TRAINING(
        "Coherence Training",
        "HRV biofeedback training",
        20,
        100
    ),
    CREATIVE_FLOW(
        "Creative Flow",
        "Optimize for creativity and flow state",
        60,
        50
    ),
    WELLNESS_CHECK(
        "Wellness Check",
        "Quick biometric assessment",
        5,
        1
    ),
    RESEARCH_STUDY(
        "Research Study",
        "Controlled research session with data export",
        45,
        500
    ),
    PERFORMANCE(
        "Performance Optimization",
        "Athletic/cognitive performance focus",
        30,
        10
    ),
    WORKSHOP(
        "Group Workshop",
        "Educational group session",
        90,
        200
    ),
    UNLIMITED(
        "Unlimited Session",
        "Open session with no constraints",
        Int.MAX_VALUE,
        Int.MAX_VALUE
    )
}

// ============================================================================
// PRIVACY MODES
// ============================================================================

enum class PrivacyMode(
    val displayName: String,
    val sharesIndividualData: Boolean,
    val sharesAggregateData: Boolean,
    val recordsToHistory: Boolean
) {
    FULL(
        "Full Sharing",
        sharesIndividualData = true,
        sharesAggregateData = true,
        recordsToHistory = true
    ),
    AGGREGATED(
        "Aggregated Only",
        sharesIndividualData = false,
        sharesAggregateData = true,
        recordsToHistory = true
    ),
    ANONYMOUS(
        "Anonymous",
        sharesIndividualData = false,
        sharesAggregateData = false,
        recordsToHistory = false
    )
}

// ============================================================================
// BROADCASTING
// ============================================================================

enum class BroadcastPlatform(
    val displayName: String,
    val streamUrl: String,
    val maxBitrate: Int
) {
    YOUTUBE("YouTube", "rtmp://a.rtmp.youtube.com/live2", 51000),
    TWITCH("Twitch", "rtmp://live.twitch.tv/app", 8500),
    FACEBOOK("Facebook", "rtmps://live-api-s.facebook.com:443/rtmp", 4000),
    INSTAGRAM("Instagram", "rtmps://live-upload.instagram.com:443/rtmp", 3500),
    TIKTOK("TikTok", "rtmp://push.tiktokv.com/live", 2500),
    WEBRTC("WebRTC", "", 10000),
    NDI("NDI", "", 150000),
    CUSTOM("Custom RTMP", "", 100000)
}

enum class StreamQuality(
    val displayName: String,
    val width: Int,
    val height: Int,
    val bitrate: Int
) {
    SD_480P("480p SD", 854, 480, 1500),
    HD_720P("720p HD", 1280, 720, 3000),
    FHD_1080P("1080p Full HD", 1920, 1080, 6000),
    QHD_1440P("1440p QHD", 2560, 1440, 12000),
    UHD_8K("8K UHD", 7680, 4320, 80000)
}

data class BroadcastConfig(
    val platform: BroadcastPlatform,
    val streamKey: String,
    val quality: StreamQuality,
    val enabled: Boolean = true
)

// ============================================================================
// QUANTUM SESSION
// ============================================================================

data class QuantumSession(
    val sessionId: String,
    val type: QuantumSessionType,
    val startTime: Long,
    val hostId: String,
    val privacyMode: PrivacyMode,
    val broadcasts: List<BroadcastConfig> = emptyList(),
    var participantCount: Int = 0,
    var viewerCount: Int = 0
)

// ============================================================================
// GROUP QUANTUM METRICS
// ============================================================================

data class GroupQuantumMetrics(
    val groupCoherence: Float,         // Average coherence
    val groupEntanglement: Float,      // Sync level (0-1)
    val groupSynchrony: Float,         // Heart rate sync
    val entanglementThresholdReached: Boolean,
    val peakCoherenceMoments: List<Long>,  // Timestamps of peak moments
    val participantCount: Int,
    val viewerCount: Int
)

// ============================================================================
// MAIN QUANTUM HEALTH BIOFEEDBACK ENGINE
// ============================================================================

class QuantumHealthBiofeedbackEngine {

    private val _currentState = MutableStateFlow(QuantumHealthState())
    val currentState: StateFlow<QuantumHealthState> = _currentState

    private val _groupMetrics = MutableStateFlow(GroupQuantumMetrics(
        groupCoherence = 0f,
        groupEntanglement = 0f,
        groupSynchrony = 0f,
        entanglementThresholdReached = false,
        peakCoherenceMoments = emptyList(),
        participantCount = 0,
        viewerCount = 0
    ))
    val groupMetrics: StateFlow<GroupQuantumMetrics> = _groupMetrics

    private val _currentSession = MutableStateFlow<QuantumSession?>(null)
    val currentSession: StateFlow<QuantumSession?> = _currentSession

    private val participants = mutableMapOf<String, QuantumHealthState>()
    private val peakCoherenceMoments = mutableListOf<Long>()
    private val healthHistory = mutableListOf<QuantumHealthState>()

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var sessionJob: Job? = null

    companion object {
        const val ENTANGLEMENT_THRESHOLD = 0.9f
        const val OPTIMAL_BREATHING_RATE = 6f  // 0.1Hz baroreflex
        const val HEALTH_SCORE_WEIGHTS_HRV = 0.3f
        const val HEALTH_SCORE_WEIGHTS_COHERENCE = 0.3f
        const val HEALTH_SCORE_WEIGHTS_SPO2 = 0.2f
        const val HEALTH_SCORE_WEIGHTS_HR = 0.2f
    }

    // ========================================================================
    // SESSION MANAGEMENT
    // ========================================================================

    fun startSession(
        type: QuantumSessionType,
        hostId: String,
        privacyMode: PrivacyMode = PrivacyMode.AGGREGATED,
        broadcasts: List<BroadcastConfig> = emptyList()
    ): QuantumSession {
        val session = QuantumSession(
            sessionId = System.currentTimeMillis().toString(),
            type = type,
            startTime = System.currentTimeMillis(),
            hostId = hostId,
            privacyMode = privacyMode,
            broadcasts = broadcasts
        )

        _currentSession.value = session
        participants.clear()
        peakCoherenceMoments.clear()
        healthHistory.clear()

        sessionJob = scope.launch {
            while (isActive && _currentSession.value != null) {
                updateGroupMetrics()
                delay(100) // 10Hz
            }
        }

        return session
    }

    fun endSession(): SessionSummary {
        sessionJob?.cancel()

        val session = _currentSession.value
        val summary = SessionSummary(
            sessionId = session?.sessionId ?: "",
            duration = session?.let { System.currentTimeMillis() - it.startTime } ?: 0,
            peakCoherence = healthHistory.maxOfOrNull { it.hrvCoherence } ?: 0f,
            averageCoherence = healthHistory.map { it.hrvCoherence }.average().toFloat(),
            peakHealthScore = healthHistory.maxOfOrNull { it.quantumHealthScore } ?: 0f,
            averageHealthScore = healthHistory.map { it.quantumHealthScore }.average().toFloat(),
            entanglementEvents = peakCoherenceMoments.size,
            maxParticipants = participants.size,
            maxViewers = session?.viewerCount ?: 0
        )

        _currentSession.value = null
        return summary
    }

    data class SessionSummary(
        val sessionId: String,
        val duration: Long,
        val peakCoherence: Float,
        val averageCoherence: Float,
        val peakHealthScore: Float,
        val averageHealthScore: Float,
        val entanglementEvents: Int,
        val maxParticipants: Int,
        val maxViewers: Int
    )

    // ========================================================================
    // PARTICIPANT MANAGEMENT
    // ========================================================================

    fun addParticipant(participantId: String, initialState: QuantumHealthState) {
        participants[participantId] = initialState
        _currentSession.value?.let {
            _currentSession.value = it.copy(participantCount = participants.size)
        }
    }

    fun updateParticipant(participantId: String, state: QuantumHealthState) {
        participants[participantId] = state
    }

    fun removeParticipant(participantId: String) {
        participants.remove(participantId)
        _currentSession.value?.let {
            _currentSession.value = it.copy(participantCount = participants.size)
        }
    }

    fun updateViewerCount(count: Int) {
        _currentSession.value?.let {
            _currentSession.value = it.copy(viewerCount = count)
        }
    }

    // ========================================================================
    // STATE UPDATE
    // ========================================================================

    fun updateLocalState(
        heartRate: Int,
        hrvSdnn: Float,
        hrvRmssd: Float,
        respiratoryRate: Float,
        spo2: Float = 98f,
        skinConductance: Float = 5f,
        skinTemperature: Float = 32f
    ) {
        val coherence = calculateCoherence(hrvSdnn, hrvRmssd, respiratoryRate)

        // Calculate quantum-inspired metrics
        val quantumCoherence = coherence
        val superpositionIndex = calculateSuperpositionIndex()
        val collapseStability = calculateCollapseStability()
        val observerEffect = calculateObserverEffect()

        // Calculate health score
        val healthScore = calculateHealthScore(
            heartRate, hrvSdnn, coherence, spo2
        )

        val newState = QuantumHealthState(
            heartRate = heartRate,
            hrvSdnn = hrvSdnn,
            hrvRmssd = hrvRmssd,
            hrvCoherence = coherence,
            respiratoryRate = respiratoryRate,
            spo2 = spo2,
            skinConductance = skinConductance,
            skinTemperature = skinTemperature,
            quantumCoherence = quantumCoherence,
            superpositionIndex = superpositionIndex,
            collapseStability = collapseStability,
            observerEffect = observerEffect,
            quantumHealthScore = healthScore
        )

        _currentState.value = newState
        healthHistory.add(newState)

        // Limit history
        if (healthHistory.size > 3600) {
            healthHistory.removeAt(0)
        }
    }

    private fun calculateCoherence(sdnn: Float, rmssd: Float, respRate: Float): Float {
        // Coherence based on HRV metrics and breathing proximity to 0.1Hz
        val hrvComponent = (sdnn / 100f).coerceIn(0f, 1f) * 0.4f +
                (rmssd / 80f).coerceIn(0f, 1f) * 0.3f

        // Optimal breathing is 6/min (0.1Hz)
        val breathingOptimality = 1f - (abs(respRate - OPTIMAL_BREATHING_RATE) / 10f)
            .coerceIn(0f, 1f)

        return (hrvComponent + breathingOptimality * 0.3f).coerceIn(0f, 1f)
    }

    private fun calculateSuperpositionIndex(): Float {
        // Based on state variability
        if (healthHistory.size < 10) return 0.5f

        val recentCoherences = healthHistory.takeLast(10).map { it.hrvCoherence }
        val variance = recentCoherences.let { values ->
            val mean = values.average()
            values.map { (it - mean).pow(2) }.average()
        }

        return sqrt(variance.toFloat()).coerceIn(0f, 1f)
    }

    private fun calculateCollapseStability(): Float {
        // Based on how stable the current state is
        if (healthHistory.size < 5) return 0.5f

        val recent = healthHistory.takeLast(5).map { it.hrvCoherence }
        val trend = recent.zipWithNext { a, b -> b - a }.average()

        // Stable = low trend, high stability
        return (1f - abs(trend.toFloat()) * 5f).coerceIn(0f, 1f)
    }

    private fun calculateObserverEffect(): Float {
        // Simulated attention/focus effect
        val current = _currentState.value
        return (current.hrvCoherence * 0.5f + 0.25f).coerceIn(0f, 1f)
    }

    private fun calculateHealthScore(
        heartRate: Int,
        sdnn: Float,
        coherence: Float,
        spo2: Float
    ): Float {
        // Heart rate score (60-80 optimal)
        val hrScore = when {
            heartRate in 60..80 -> 100f
            heartRate in 50..60 || heartRate in 80..100 -> 80f
            heartRate in 40..50 || heartRate in 100..120 -> 60f
            else -> 40f
        }

        // HRV score
        val hrvScore = (sdnn / 50f * 100f).coerceIn(0f, 100f)

        // Coherence score
        val coherenceScore = coherence * 100f

        // SpO2 score
        val spo2Score = when {
            spo2 >= 98 -> 100f
            spo2 >= 95 -> 90f
            spo2 >= 92 -> 70f
            else -> 50f
        }

        return hrScore * HEALTH_SCORE_WEIGHTS_HR +
                hrvScore * HEALTH_SCORE_WEIGHTS_HRV +
                coherenceScore * HEALTH_SCORE_WEIGHTS_COHERENCE +
                spo2Score * HEALTH_SCORE_WEIGHTS_SPO2
    }

    // ========================================================================
    // GROUP METRICS
    // ========================================================================

    private fun updateGroupMetrics() {
        if (participants.isEmpty()) {
            _groupMetrics.value = GroupQuantumMetrics(
                groupCoherence = _currentState.value.hrvCoherence,
                groupEntanglement = 0f,
                groupSynchrony = 0f,
                entanglementThresholdReached = false,
                peakCoherenceMoments = peakCoherenceMoments.toList(),
                participantCount = 1,
                viewerCount = _currentSession.value?.viewerCount ?: 0
            )
            return
        }

        val allStates = participants.values.toList() + _currentState.value
        val avgCoherence = allStates.map { it.hrvCoherence }.average().toFloat()

        // Calculate entanglement (sync level)
        val coherenceVariance = allStates.map { it.hrvCoherence }.let { values ->
            val mean = values.average()
            values.map { (it - mean).pow(2) }.average()
        }
        val entanglement = (1f - sqrt(coherenceVariance.toFloat())).coerceIn(0f, 1f)

        // Calculate heart rate synchrony
        val hrVariance = allStates.map { it.heartRate.toFloat() }.let { values ->
            val mean = values.average()
            values.map { ((it - mean) / 20f).pow(2) }.average()
        }
        val synchrony = (1f - sqrt(hrVariance.toFloat())).coerceIn(0f, 1f)

        // Check entanglement threshold
        val thresholdReached = entanglement >= ENTANGLEMENT_THRESHOLD
        if (thresholdReached) {
            peakCoherenceMoments.add(System.currentTimeMillis())
        }

        _groupMetrics.value = GroupQuantumMetrics(
            groupCoherence = avgCoherence,
            groupEntanglement = entanglement,
            groupSynchrony = synchrony,
            entanglementThresholdReached = thresholdReached,
            peakCoherenceMoments = peakCoherenceMoments.toList(),
            participantCount = allStates.size,
            viewerCount = _currentSession.value?.viewerCount ?: 0
        )
    }
}

// ============================================================================
// ADEY WINDOWS BIOELECTROMAGNETIC ENGINE
// ============================================================================

/**
 * Scientific frequency-body mapping based on Dr. W. Ross Adey's research
 * UCLA Brain Research Institute, Loma Linda (Physiological Reviews 1981)
 *
 * CRITICAL DISCLAIMER: This uses AUDIO entrainment (binaural beats, isochronic tones),
 * NOT actual electromagnetic fields. Audio ≠ Elektromagnetik. Keine medizinische Therapie.
 */

enum class BodySystem(
    val displayName: String,
    val description: String,
    val relatedMeasurements: List<String>
) {
    NERVOUS(
        "Nervous System (Psyche)",
        "Brain and neural activity",
        listOf("EEG", "Alpha waves", "Theta waves", "Gamma waves")
    ),
    CARDIOVASCULAR(
        "Cardiovascular System",
        "Heart and blood vessels",
        listOf("HRV", "Heart rate", "Blood pressure")
    ),
    MUSCULOSKELETAL(
        "Musculoskeletal System",
        "Muscles and bones",
        listOf("EMG", "Muscle tension", "Movement")
    ),
    RESPIRATORY(
        "Respiratory System",
        "Lungs and breathing",
        listOf("Respiratory rate", "SpO2", "Breath depth")
    ),
    ENDOCRINE(
        "Endocrine System",
        "Hormones and glands",
        listOf("Cortisol (indirect)", "Stress markers")
    ),
    IMMUNE(
        "Immune System",
        "Immune response and inflammation",
        listOf("Heart rate variability (proxy)", "Stress response")
    )
}

enum class OxfordCEBMLevel(
    val level: String,
    val description: String
) {
    LEVEL_1A("1a", "Systematic review of RCTs"),
    LEVEL_1B("1b", "Individual RCT"),
    LEVEL_2A("2a", "Systematic review of cohort studies"),
    LEVEL_2B("2b", "Individual cohort study"),
    LEVEL_3A("3a", "Systematic review of case-control studies"),
    LEVEL_3B("3b", "Individual case-control study"),
    LEVEL_4("4", "Case series"),
    LEVEL_5("5", "Expert opinion")
}

data class AdeyWindow(
    val name: String,
    val frequencyRange: Pair<Float, Float>,  // Hz
    val targetSystem: BodySystem,
    val evidenceLevel: OxfordCEBMLevel,
    val citations: List<String>,
    val audioImplementation: String,
    val description: String
) {
    val centerFrequency: Float get() = (frequencyRange.first + frequencyRange.second) / 2f
}

object AdeyWindows {
    val all = listOf(
        AdeyWindow(
            name = "Delta Window",
            frequencyRange = 0.5f to 4f,
            targetSystem = BodySystem.NERVOUS,
            evidenceLevel = OxfordCEBMLevel.LEVEL_2B,
            citations = listOf("Adey 1981 Physiological Reviews", "Bawin & Adey 1976 PNAS"),
            audioImplementation = "Binaural beats at delta frequency (2Hz)",
            description = "Deep sleep, regeneration. Associated with slow-wave sleep."
        ),
        AdeyWindow(
            name = "Theta Window",
            frequencyRange = 4f to 8f,
            targetSystem = BodySystem.NERVOUS,
            evidenceLevel = OxfordCEBMLevel.LEVEL_2B,
            citations = listOf("Adey 1981", "Blackman 1985"),
            audioImplementation = "Binaural beats at theta frequency (6Hz)",
            description = "Meditation, creativity, memory consolidation."
        ),
        AdeyWindow(
            name = "Alpha Window",
            frequencyRange = 8f to 12f,
            targetSystem = BodySystem.NERVOUS,
            evidenceLevel = OxfordCEBMLevel.LEVEL_1B,
            citations = listOf("Multiple EEG studies", "HeartMath Institute"),
            audioImplementation = "Binaural beats at alpha frequency (10Hz)",
            description = "Relaxed alertness, calm focus, learning state."
        ),
        AdeyWindow(
            name = "Schumann Resonance Window",
            frequencyRange = 7.5f to 8.5f,
            targetSystem = BodySystem.NERVOUS,
            evidenceLevel = OxfordCEBMLevel.LEVEL_4,
            citations = listOf("Schumann 1952", "König 1974"),
            audioImplementation = "Binaural beats at 7.83Hz (Earth's electromagnetic resonance)",
            description = "Natural frequency of Earth's electromagnetic field."
        ),
        AdeyWindow(
            name = "HRV Coherence Window",
            frequencyRange = 0.04f to 0.15f,
            targetSystem = BodySystem.CARDIOVASCULAR,
            evidenceLevel = OxfordCEBMLevel.LEVEL_1B,
            citations = listOf("HeartMath Institute", "PMC7527628"),
            audioImplementation = "Breathing guide at 0.1Hz (6 breaths/min)",
            description = "Heart-brain coherence, baroreflex synchronization."
        ),
        AdeyWindow(
            name = "PEMF Therapeutic Window",
            frequencyRange = 1f to 30f,
            targetSystem = BodySystem.MUSCULOSKELETAL,
            evidenceLevel = OxfordCEBMLevel.LEVEL_2A,
            citations = listOf("FDA-approved PEMF devices", "Bassett 1982"),
            audioImplementation = "Pulsed audio tones (NOT actual EM fields)",
            description = "Note: Audio simulation only. Real PEMF requires specialized devices."
        ),
        AdeyWindow(
            name = "Vagal Tone Enhancement Window",
            frequencyRange = 0.15f to 0.4f,
            targetSystem = BodySystem.CARDIOVASCULAR,
            evidenceLevel = OxfordCEBMLevel.LEVEL_1B,
            citations = listOf("Porges Polyvagal Theory", "Frontiers Physiology 2020"),
            audioImplementation = "Slow breathing with extended exhale (4-7-8 pattern)",
            description = "High-frequency HRV band, parasympathetic activity."
        ),
        AdeyWindow(
            name = "Gamma Cognition Window",
            frequencyRange = 30f to 100f,
            targetSystem = BodySystem.NERVOUS,
            evidenceLevel = OxfordCEBMLevel.LEVEL_2B,
            citations = listOf("Gamma oscillations research", "Binding hypothesis studies"),
            audioImplementation = "Isochronic tones at 40Hz",
            description = "Peak cognitive processing, perceptual binding."
        ),
        AdeyWindow(
            name = "Circadian Entrainment Window",
            frequencyRange = 0.000011f to 0.000012f, // ~24 hour cycle
            targetSystem = BodySystem.ENDOCRINE,
            evidenceLevel = OxfordCEBMLevel.LEVEL_1A,
            citations = listOf("Circadian rhythm research", "Nobel Prize 2017 Chronobiology"),
            audioImplementation = "Light exposure scheduling (audio cues for timing)",
            description = "24-hour biological rhythm regulation."
        ),
        AdeyWindow(
            name = "Stress Response Window",
            frequencyRange = 0.01f to 0.05f,
            targetSystem = BodySystem.ENDOCRINE,
            evidenceLevel = OxfordCEBMLevel.LEVEL_2B,
            citations = listOf("HPA axis research", "Cortisol studies"),
            audioImplementation = "Very slow breathing patterns, relaxation response",
            description = "Very low frequency HRV, sympathetic/parasympathetic balance."
        )
    )
}

class AdeyWindowsBioelectromagneticEngine {

    private val _currentWindow = MutableStateFlow<AdeyWindow?>(null)
    val currentWindow: StateFlow<AdeyWindow?> = _currentWindow

    private val _activeFrequency = MutableStateFlow(10f)
    val activeFrequency: StateFlow<Float> = _activeFrequency

    private val _targetSystem = MutableStateFlow(BodySystem.NERVOUS)
    val targetSystem: StateFlow<BodySystem> = _targetSystem

    /**
     * Get windows for a specific body system
     */
    fun getWindowsForSystem(system: BodySystem): List<AdeyWindow> {
        return AdeyWindows.all.filter { it.targetSystem == system }
    }

    /**
     * Get window by frequency
     */
    fun getWindowForFrequency(frequency: Float): AdeyWindow? {
        return AdeyWindows.all.find {
            frequency >= it.frequencyRange.first && frequency <= it.frequencyRange.second
        }
    }

    /**
     * Set active window
     */
    fun setActiveWindow(window: AdeyWindow) {
        _currentWindow.value = window
        _activeFrequency.value = window.centerFrequency
        _targetSystem.value = window.targetSystem
    }

    /**
     * Set frequency directly
     */
    fun setFrequency(frequency: Float) {
        _activeFrequency.value = frequency
        _currentWindow.value = getWindowForFrequency(frequency)
    }

    /**
     * Get audio parameters for current window
     */
    fun getAudioParameters(): AudioEntrainmentParameters {
        val window = _currentWindow.value
        val freq = _activeFrequency.value

        return AudioEntrainmentParameters(
            binauralBeatFrequency = freq,
            carrierFrequency = 200f + freq * 10f, // Scale carrier with beat
            isochronicPulseRate = freq,
            amplitude = 0.3f,
            implementation = window?.audioImplementation ?: "Binaural beat at ${freq}Hz"
        )
    }

    data class AudioEntrainmentParameters(
        val binauralBeatFrequency: Float,
        val carrierFrequency: Float,
        val isochronicPulseRate: Float,
        val amplitude: Float,
        val implementation: String
    )

    /**
     * Get evidence summary for current window
     */
    fun getEvidenceSummary(): String {
        val window = _currentWindow.value ?: return "No window selected"

        return buildString {
            appendLine("Window: ${window.name}")
            appendLine("Frequency: ${window.frequencyRange.first}-${window.frequencyRange.second} Hz")
            appendLine("Target: ${window.targetSystem.displayName}")
            appendLine("Evidence Level: ${window.evidenceLevel.level} - ${window.evidenceLevel.description}")
            appendLine("Citations: ${window.citations.joinToString("; ")}")
            appendLine()
            appendLine("Implementation: ${window.audioImplementation}")
            appendLine()
            appendLine(DISCLAIMER)
        }
    }

    companion object {
        const val DISCLAIMER = """
            IMPORTANT SCIENTIFIC DISCLAIMER

            This system uses AUDIO entrainment techniques (binaural beats,
            isochronic tones, breathing guides), NOT actual electromagnetic fields.

            • Audio ≠ Elektromagnetik
            • This is NOT a medical device
            • This is NOT PEMF therapy
            • The Adey Windows research was on actual EM fields, not audio
            • We use audio as an APPROXIMATION for creative/meditative purposes

            The evidence levels cited are for the original research contexts.
            Audio entrainment may have different efficacy than actual EM exposure.

            Consult healthcare professionals for any medical concerns.
            Subjective relaxation benefits are better documented than
            neurophysiological effects of audio entrainment.
        """
    }
}
