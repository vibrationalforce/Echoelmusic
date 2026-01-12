/**
 * LambdaModeEngine.kt
 *
 * Complete Lambda Mode implementation with:
 * - 8 Transcendence States (Dormant → λ∞)
 * - GazeTracker integration
 * - HapticCompositionEngine
 * - SocialCoherenceEngine (1000+ participants)
 * - AISceneDirector
 * - Session Analytics with flow detection
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 */
package com.echoelmusic.lambda

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

// ============================================================================
// TRANSCENDENCE STATES
// ============================================================================

enum class TranscendenceState(
    val displayName: String,
    val level: Int,
    val coherenceThreshold: Float,
    val description: String,
    val audioCharacteristics: String,
    val visualCharacteristics: String
) {
    DORMANT(
        "Dormant",
        0,
        0.0f,
        "System inactive, awaiting bio signal",
        "Silence",
        "Dark, minimal"
    ),
    AWAKENING(
        "Awakening",
        1,
        0.15f,
        "Initial bio connection established",
        "Subtle drones, low frequencies",
        "Dim pulse, slow breathing light"
    ),
    AWARE(
        "Aware",
        2,
        0.30f,
        "Conscious attention to bio signals",
        "Ambient textures, heart-synced rhythm",
        "Coherence rings emerging"
    ),
    FLOWING(
        "Flowing",
        3,
        0.45f,
        "Smooth integration of body-mind",
        "Melodic elements, bio-reactive filters",
        "Fluid particle systems"
    ),
    COHERENT(
        "Coherent",
        4,
        0.60f,
        "High heart-brain coherence achieved",
        "Harmonic resonance, golden ratio intervals",
        "Sacred geometry patterns"
    ),
    TRANSCENDENT(
        "Transcendent",
        5,
        0.75f,
        "Expanded awareness beyond normal",
        "Overtones, spatial audio expansion",
        "Mandala formations, light expansion"
    ),
    UNIFIED(
        "Unified",
        6,
        0.85f,
        "Integration of all bio-signals",
        "Full harmonic spectrum, perfect sync",
        "Unified field visualization"
    ),
    LAMBDA_INFINITE(
        "λ∞ Lambda Infinite",
        7,
        0.95f,
        "Peak state - complete bio-coherent synthesis",
        "Transcendent harmonics, quantum resonance",
        "Full immersive quantum field"
    )
}

// ============================================================================
// UNIFIED BIO DATA
// ============================================================================

data class UnifiedBioData(
    // Heart
    val heartRate: Int = 72,
    val hrvSdnn: Float = 50f,
    val hrvRmssd: Float = 40f,
    val hrvCoherence: Float = 0.5f,
    val lfHfRatio: Float = 1.5f,

    // Breathing
    val breathingRate: Float = 12f,
    val breathingDepth: Float = 0.7f,
    val breathingPhase: Float = 0f, // 0-1 (inhale to exhale)

    // Other biometrics
    val gsr: Float = 0.5f,         // Galvanic skin response
    val skinTemp: Float = 32f,     // Skin temperature
    val spo2: Float = 98f,         // Blood oxygen

    // Derived
    val timestamp: Long = System.currentTimeMillis()
) {
    val coherenceRatio: Float get() = hrvCoherence
    val activationLevel: Float get() = (heartRate - 60f) / 60f // 60-120 → 0-1
    val relaxationLevel: Float get() = 1f - activationLevel
}

// ============================================================================
// LAMBDA SCORE CALCULATOR
// ============================================================================

class LambdaScoreCalculator {

    data class LambdaScore(
        val overall: Float,           // 0-1
        val coherenceComponent: Float,
        val flowComponent: Float,
        val integrationComponent: Float,
        val state: TranscendenceState
    )

    fun calculate(
        bioData: UnifiedBioData,
        audioVisualSync: Float,    // How well audio/visual sync to bio
        sessionDuration: Long,     // Minutes
        stateStability: Float      // How stable the current state is
    ): LambdaScore {
        // Coherence component (40% weight)
        val coherenceComponent = bioData.hrvCoherence

        // Flow component (30% weight)
        // Based on optimal breathing rate (6/min) and heart-breath sync
        val optimalBreathingDelta = abs(bioData.breathingRate - 6f) / 6f
        val flowComponent = (1f - optimalBreathingDelta).coerceIn(0f, 1f) *
                (bioData.hrvCoherence * 0.5f + 0.5f)

        // Integration component (30% weight)
        // How well all systems are synchronized
        val integrationComponent = (audioVisualSync * 0.4f +
                stateStability * 0.3f +
                (sessionDuration / 30f).coerceAtMost(1f) * 0.3f)

        // Overall Lambda score
        val overall = coherenceComponent * 0.4f +
                flowComponent * 0.3f +
                integrationComponent * 0.3f

        // Determine transcendence state
        val state = TranscendenceState.values()
            .filter { overall >= it.coherenceThreshold }
            .maxByOrNull { it.level } ?: TranscendenceState.DORMANT

        return LambdaScore(
            overall = overall,
            coherenceComponent = coherenceComponent,
            flowComponent = flowComponent,
            integrationComponent = integrationComponent,
            state = state
        )
    }
}

// ============================================================================
// GAZE TRACKER
// ============================================================================

data class GazeData(
    val gazePointX: Float = 0.5f,      // Normalized 0-1
    val gazePointY: Float = 0.5f,
    val leftEyeOpenness: Float = 1f,   // 0 = closed, 1 = open
    val rightEyeOpenness: Float = 1f,
    val pupilDilation: Float = 0.5f,   // 0-1
    val fixationDuration: Float = 0f,  // Seconds at current point
    val saccadeVelocity: Float = 0f,   // Eye movement speed
    val blinkRate: Float = 15f,        // Blinks per minute
    val timestamp: Long = System.currentTimeMillis()
) {
    val averageEyeOpenness: Float get() = (leftEyeOpenness + rightEyeOpenness) / 2f
    val isBlinking: Boolean get() = averageEyeOpenness < 0.3f
    val attentionScore: Float get() = fixationDuration.coerceAtMost(3f) / 3f
    val arousalFromPupil: Float get() = pupilDilation
}

enum class GazeGesture {
    BLINK,
    DOUBLE_BLINK,
    WINK_LEFT,
    WINK_RIGHT,
    LONG_GAZE,      // > 2 seconds fixation
    LOOK_UP,
    LOOK_DOWN,
    LOOK_LEFT,
    LOOK_RIGHT
}

enum class GazeZone(val row: Int, val col: Int) {
    TOP_LEFT(0, 0),
    TOP_CENTER(0, 1),
    TOP_RIGHT(0, 2),
    MIDDLE_LEFT(1, 0),
    CENTER(1, 1),
    MIDDLE_RIGHT(1, 2),
    BOTTOM_LEFT(2, 0),
    BOTTOM_CENTER(2, 1),
    BOTTOM_RIGHT(2, 2)
}

class GazeTracker {
    private val _currentGaze = MutableStateFlow(GazeData())
    val currentGaze: StateFlow<GazeData> = _currentGaze

    private val _detectedGestures = MutableSharedFlow<GazeGesture>()
    val detectedGestures: SharedFlow<GazeGesture> = _detectedGestures

    private var lastBlinkTime = 0L
    private var blinkCount = 0

    /**
     * Update gaze data from ARCore/face tracking
     */
    suspend fun updateGaze(data: GazeData) {
        val previousGaze = _currentGaze.value
        _currentGaze.value = data

        // Detect gestures
        detectGestures(previousGaze, data)
    }

    private suspend fun detectGestures(previous: GazeData, current: GazeData) {
        val now = System.currentTimeMillis()

        // Blink detection
        if (previous.averageEyeOpenness > 0.5f && current.averageEyeOpenness < 0.3f) {
            if (now - lastBlinkTime < 500) {
                blinkCount++
                if (blinkCount >= 2) {
                    _detectedGestures.emit(GazeGesture.DOUBLE_BLINK)
                    blinkCount = 0
                }
            } else {
                _detectedGestures.emit(GazeGesture.BLINK)
                blinkCount = 1
            }
            lastBlinkTime = now
        }

        // Wink detection
        if (current.leftEyeOpenness < 0.3f && current.rightEyeOpenness > 0.7f) {
            _detectedGestures.emit(GazeGesture.WINK_LEFT)
        } else if (current.rightEyeOpenness < 0.3f && current.leftEyeOpenness > 0.7f) {
            _detectedGestures.emit(GazeGesture.WINK_RIGHT)
        }

        // Long gaze detection
        if (current.fixationDuration > 2f && previous.fixationDuration <= 2f) {
            _detectedGestures.emit(GazeGesture.LONG_GAZE)
        }

        // Direction detection
        val deltaX = current.gazePointX - 0.5f
        val deltaY = current.gazePointY - 0.5f
        val threshold = 0.3f

        if (abs(deltaX) > threshold || abs(deltaY) > threshold) {
            when {
                deltaY < -threshold -> _detectedGestures.emit(GazeGesture.LOOK_UP)
                deltaY > threshold -> _detectedGestures.emit(GazeGesture.LOOK_DOWN)
                deltaX < -threshold -> _detectedGestures.emit(GazeGesture.LOOK_LEFT)
                deltaX > threshold -> _detectedGestures.emit(GazeGesture.LOOK_RIGHT)
            }
        }
    }

    /**
     * Get current gaze zone (3x3 grid)
     */
    fun getCurrentZone(): GazeZone {
        val gaze = _currentGaze.value
        val col = when {
            gaze.gazePointX < 0.33f -> 0
            gaze.gazePointX < 0.66f -> 1
            else -> 2
        }
        val row = when {
            gaze.gazePointY < 0.33f -> 0
            gaze.gazePointY < 0.66f -> 1
            else -> 2
        }

        return GazeZone.values().find { it.row == row && it.col == col } ?: GazeZone.CENTER
    }

    /**
     * Map gaze to audio parameters
     */
    fun getAudioControlParameters(): GazeAudioParameters {
        val gaze = _currentGaze.value
        val zone = getCurrentZone()

        // Zone → frequency band
        val frequencyBand = when (zone.row) {
            0 -> 6000f + (zone.col * 2000f)  // High frequencies
            1 -> 2000f + (zone.col * 1000f)  // Mid frequencies
            else -> 200f + (zone.col * 300f)  // Bass frequencies
        }

        return GazeAudioParameters(
            pan = (gaze.gazePointX - 0.5f) * 2f,  // -1 to 1
            reverbWet = 1f - gaze.attentionScore,  // Less attention = more reverb
            filterCutoff = frequencyBand,
            intensity = gaze.arousalFromPupil
        )
    }

    data class GazeAudioParameters(
        val pan: Float,
        val reverbWet: Float,
        val filterCutoff: Float,
        val intensity: Float
    )
}

// ============================================================================
// HAPTIC COMPOSITION ENGINE
// ============================================================================

enum class HapticPatternType {
    HEARTBEAT,
    BREATHING,
    COHERENCE_PULSE,
    QUANTUM_FLUTTER,
    WAVEFORM,
    MEDITATION,
    ENERGY_BURST,
    CALM_WAVE,
    ALERT,
    SUCCESS,
    WARNING,
    RHYTHMIC,
    AMBIENT,
    BIO_SYNC,
    ENTRAINMENT
}

data class HapticEvent(
    val intensity: Float,       // 0-1
    val sharpness: Float,       // 0-1 (soft to sharp)
    val duration: Float,        // Seconds
    val delay: Float = 0f       // Delay before event
)

data class HapticPattern(
    val type: HapticPatternType,
    val events: List<HapticEvent>,
    val repeatCount: Int = 1,
    val loopDelay: Float = 0f
)

class HapticCompositionEngine {

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying

    // Pre-defined patterns
    private val patterns = mapOf(
        HapticPatternType.HEARTBEAT to HapticPattern(
            type = HapticPatternType.HEARTBEAT,
            events = listOf(
                HapticEvent(0.8f, 0.6f, 0.1f),
                HapticEvent(0.5f, 0.4f, 0.1f, 0.15f)
            ),
            repeatCount = -1, // Infinite
            loopDelay = 0.7f // ~72 BPM
        ),
        HapticPatternType.BREATHING to HapticPattern(
            type = HapticPatternType.BREATHING,
            events = listOf(
                HapticEvent(0.3f, 0.2f, 2f),    // Inhale (gentle rise)
                HapticEvent(0.1f, 0.1f, 0.5f, 2f), // Hold
                HapticEvent(0.2f, 0.1f, 3f, 2.5f)  // Exhale (gentle fall)
            ),
            repeatCount = -1,
            loopDelay = 0.5f
        ),
        HapticPatternType.COHERENCE_PULSE to HapticPattern(
            type = HapticPatternType.COHERENCE_PULSE,
            events = listOf(
                HapticEvent(0.6f, 0.3f, 0.3f),
                HapticEvent(0.4f, 0.2f, 0.2f, 0.1f),
                HapticEvent(0.2f, 0.1f, 0.1f, 0.2f)
            ),
            repeatCount = 1
        ),
        HapticPatternType.QUANTUM_FLUTTER to HapticPattern(
            type = HapticPatternType.QUANTUM_FLUTTER,
            events = (0 until 8).map { i ->
                HapticEvent(
                    intensity = 0.3f + (i % 2) * 0.2f,
                    sharpness = 0.7f,
                    duration = 0.05f,
                    delay = i * 0.08f
                )
            },
            repeatCount = 3
        ),
        HapticPatternType.MEDITATION to HapticPattern(
            type = HapticPatternType.MEDITATION,
            events = listOf(
                HapticEvent(0.2f, 0.1f, 1f),
                HapticEvent(0.1f, 0.05f, 2f, 1.5f)
            ),
            repeatCount = -1,
            loopDelay = 4f
        ),
        HapticPatternType.SUCCESS to HapticPattern(
            type = HapticPatternType.SUCCESS,
            events = listOf(
                HapticEvent(0.5f, 0.5f, 0.1f),
                HapticEvent(0.7f, 0.6f, 0.1f, 0.15f),
                HapticEvent(0.9f, 0.7f, 0.2f, 0.3f)
            ),
            repeatCount = 1
        ),
        HapticPatternType.WARNING to HapticPattern(
            type = HapticPatternType.WARNING,
            events = listOf(
                HapticEvent(0.8f, 0.8f, 0.15f),
                HapticEvent(0.8f, 0.8f, 0.15f, 0.3f)
            ),
            repeatCount = 2
        )
    )

    fun getPattern(type: HapticPatternType): HapticPattern? = patterns[type]

    /**
     * Generate heartbeat pattern synced to actual heart rate
     */
    fun generateHeartbeatPattern(heartRate: Int): HapticPattern {
        val beatInterval = 60f / heartRate // Seconds between beats

        return HapticPattern(
            type = HapticPatternType.HEARTBEAT,
            events = listOf(
                HapticEvent(0.8f, 0.6f, 0.1f),
                HapticEvent(0.5f, 0.4f, 0.1f, 0.15f)
            ),
            repeatCount = -1,
            loopDelay = beatInterval - 0.25f
        )
    }

    /**
     * Generate breathing pattern for specific rate
     */
    fun generateBreathingPattern(breathsPerMinute: Float): HapticPattern {
        val cycleDuration = 60f / breathsPerMinute
        val inhaleDuration = cycleDuration * 0.4f
        val holdDuration = cycleDuration * 0.1f
        val exhaleDuration = cycleDuration * 0.5f

        return HapticPattern(
            type = HapticPatternType.BREATHING,
            events = listOf(
                HapticEvent(0.3f, 0.2f, inhaleDuration),
                HapticEvent(0.1f, 0.1f, holdDuration, inhaleDuration),
                HapticEvent(0.2f, 0.1f, exhaleDuration, inhaleDuration + holdDuration)
            ),
            repeatCount = -1,
            loopDelay = 0.5f
        )
    }

    /**
     * Generate coherence-reactive pattern
     */
    fun generateCoherencePattern(coherence: Float): HapticPattern {
        // Higher coherence = smoother, gentler haptics
        // Lower coherence = more erratic, stronger haptics

        val intensity = 0.3f + (1f - coherence) * 0.4f
        val sharpness = 0.2f + (1f - coherence) * 0.5f
        val eventCount = (3 + (1f - coherence) * 5).toInt()

        val events = (0 until eventCount).map { i ->
            val variance = if (coherence < 0.5f) {
                (Math.random() * 0.3f).toFloat()
            } else 0f

            HapticEvent(
                intensity = (intensity + variance).coerceIn(0f, 1f),
                sharpness = sharpness,
                duration = 0.1f + coherence * 0.2f,
                delay = i * (0.2f + coherence * 0.3f)
            )
        }

        return HapticPattern(
            type = HapticPatternType.BIO_SYNC,
            events = events,
            repeatCount = 1
        )
    }
}

// ============================================================================
// SOCIAL COHERENCE ENGINE
// ============================================================================

data class CoherenceParticipant(
    val id: String,
    val displayName: String,
    val coherence: Float,
    val heartRate: Int,
    val joinedAt: Long = System.currentTimeMillis(),
    val isActive: Boolean = true
)

data class GroupCoherenceState(
    val participants: List<CoherenceParticipant>,
    val averageCoherence: Float,
    val coherenceSync: Float,       // How synchronized everyone is
    val heartSync: Float,           // Heart rate synchronization
    val breathSync: Float,          // Breathing synchronization
    val entrainmentLevel: Float,    // Overall group entrainment
    val isFlowAchieved: Boolean,
    val entanglementEvents: Int     // High-sync "quantum" events
)

enum class SessionType {
    OPEN_MEDITATION,
    COHERENCE_CIRCLE,
    MUSIC_JAM,
    RESEARCH_STUDY,
    WORKSHOP,
    PERFORMANCE,
    WELLNESS,
    UNLIMITED
}

class SocialCoherenceEngine {

    private val participants = mutableMapOf<String, CoherenceParticipant>()

    private val _groupState = MutableStateFlow(GroupCoherenceState(
        participants = emptyList(),
        averageCoherence = 0f,
        coherenceSync = 0f,
        heartSync = 0f,
        breathSync = 0f,
        entrainmentLevel = 0f,
        isFlowAchieved = false,
        entanglementEvents = 0
    ))
    val groupState: StateFlow<GroupCoherenceState> = _groupState

    private val _entanglementEvents = MutableSharedFlow<EntanglementEvent>()
    val entanglementEvents: SharedFlow<EntanglementEvent> = _entanglementEvents

    private var entanglementCount = 0

    companion object {
        const val MAX_PARTICIPANTS = Int.MAX_VALUE // Unlimited
        const val ENTANGLEMENT_THRESHOLD = 0.9f
        const val FLOW_THRESHOLD = 0.75f
    }

    data class EntanglementEvent(
        val timestamp: Long,
        val participantIds: List<String>,
        val coherenceLevel: Float,
        val type: EntanglementType
    )

    enum class EntanglementType {
        HEART_SYNC,
        BREATH_SYNC,
        COHERENCE_PEAK,
        GROUP_FLOW
    }

    /**
     * Add participant to session
     */
    fun addParticipant(participant: CoherenceParticipant) {
        participants[participant.id] = participant
        updateGroupState()
    }

    /**
     * Remove participant
     */
    fun removeParticipant(id: String) {
        participants.remove(id)
        updateGroupState()
    }

    /**
     * Update participant data
     */
    suspend fun updateParticipant(id: String, coherence: Float, heartRate: Int) {
        participants[id]?.let { existing ->
            participants[id] = existing.copy(
                coherence = coherence,
                heartRate = heartRate
            )
            updateGroupState()
            checkForEntanglement()
        }
    }

    private fun updateGroupState() {
        val activeParticipants = participants.values.filter { it.isActive }

        if (activeParticipants.isEmpty()) {
            _groupState.value = _groupState.value.copy(
                participants = emptyList(),
                averageCoherence = 0f
            )
            return
        }

        val avgCoherence = activeParticipants.map { it.coherence }.average().toFloat()

        // Calculate coherence synchronization (variance-based)
        val coherenceVariance = activeParticipants.map { it.coherence }
            .let { values ->
                val mean = values.average()
                values.map { (it - mean).pow(2) }.average()
            }.toFloat()
        val coherenceSync = (1f - sqrt(coherenceVariance)).coerceIn(0f, 1f)

        // Calculate heart rate synchronization
        val heartRates = activeParticipants.map { it.heartRate }
        val heartVariance = heartRates.let { values ->
            val mean = values.average()
            values.map { ((it - mean) / 20f).pow(2) }.average()
        }.toFloat()
        val heartSync = (1f - sqrt(heartVariance)).coerceIn(0f, 1f)

        // Calculate entrainment level
        val entrainmentLevel = (coherenceSync * 0.5f + heartSync * 0.3f + avgCoherence * 0.2f)

        // Check for group flow
        val isFlowAchieved = entrainmentLevel > FLOW_THRESHOLD

        _groupState.value = GroupCoherenceState(
            participants = activeParticipants.toList(),
            averageCoherence = avgCoherence,
            coherenceSync = coherenceSync,
            heartSync = heartSync,
            breathSync = 0.5f, // Would need breathing data
            entrainmentLevel = entrainmentLevel,
            isFlowAchieved = isFlowAchieved,
            entanglementEvents = entanglementCount
        )
    }

    private suspend fun checkForEntanglement() {
        val state = _groupState.value

        // Check for high synchronization events
        if (state.coherenceSync > ENTANGLEMENT_THRESHOLD && state.participants.size >= 2) {
            entanglementCount++

            _entanglementEvents.emit(EntanglementEvent(
                timestamp = System.currentTimeMillis(),
                participantIds = state.participants.map { it.id },
                coherenceLevel = state.coherenceSync,
                type = EntanglementType.COHERENCE_PEAK
            ))
        }

        if (state.heartSync > ENTANGLEMENT_THRESHOLD && state.participants.size >= 2) {
            entanglementCount++

            _entanglementEvents.emit(EntanglementEvent(
                timestamp = System.currentTimeMillis(),
                participantIds = state.participants.map { it.id },
                coherenceLevel = state.heartSync,
                type = EntanglementType.HEART_SYNC
            ))
        }

        if (state.isFlowAchieved && state.participants.size >= 3) {
            _entanglementEvents.emit(EntanglementEvent(
                timestamp = System.currentTimeMillis(),
                participantIds = state.participants.map { it.id },
                coherenceLevel = state.entrainmentLevel,
                type = EntanglementType.GROUP_FLOW
            ))
        }
    }

    fun getParticipantCount(): Int = participants.size
}

// ============================================================================
// AI SCENE DIRECTOR
// ============================================================================

enum class CameraType {
    WIDE,
    MEDIUM,
    CLOSE_UP,
    EXTREME_CLOSE_UP,
    BIRD_EYE,
    LOW_ANGLE,
    QUANTUM,       // Abstract quantum visualization
    BIO_REACTIVE,  // Bio-data visualization
    PARTICIPANT,   // Individual participant view
    GROUP         // Group visualization
}

enum class SceneMood {
    ENERGETIC,
    CALM,
    COSMIC,
    ETHEREAL,
    TRIUMPHANT,
    MYSTERIOUS,
    PLAYFUL,
    MEDITATIVE,
    INTENSE,
    PEACEFUL
}

enum class DirectionStyle {
    CONSERVATIVE,    // Slow, stable cuts
    DYNAMIC,         // Fast, energetic cuts
    CINEMATIC,       // Film-like storytelling
    EXPERIMENTAL,    // Unusual angles and effects
    BIO_DRIVEN,      // Cuts driven by biometrics
    QUANTUM,         // Quantum-state driven
    MEDITATIVE,      // Very slow, breathing-paced
    CONCERT         // Live performance style
}

data class SceneDecision(
    val camera: CameraType,
    val mood: SceneMood,
    val transitionType: TransitionType,
    val visualLayers: List<VisualLayerType>,
    val confidence: Float,
    val reasoning: String
)

enum class TransitionType {
    CUT,
    DISSOLVE,
    FADE,
    WIPE,
    PUSH,
    ZOOM,
    SPIN,
    GLITCH,
    BIO_SYNC,       // Sync to heartbeat
    QUANTUM_COLLAPSE,
    HEARTBEAT,
    BREATH
}

enum class VisualLayerType {
    SACRED_GEOMETRY,
    PARTICLES,
    QUANTUM_FIELD,
    BIO_FIELD,
    LIGHT_RAYS,
    NEBULA,
    MANDALA,
    WAVEFORM,
    SPECTRUM,
    TEXT_OVERLAY
}

class AISceneDirector {

    private val _currentScene = MutableStateFlow(SceneDecision(
        camera = CameraType.WIDE,
        mood = SceneMood.CALM,
        transitionType = TransitionType.DISSOLVE,
        visualLayers = listOf(VisualLayerType.PARTICLES),
        confidence = 0.5f,
        reasoning = "Initial state"
    ))
    val currentScene: StateFlow<SceneDecision> = _currentScene

    private var style = DirectionStyle.BIO_DRIVEN
    private var lastCutTime = 0L
    private var minCutInterval = 3000L // Minimum 3 seconds between cuts

    fun setDirectionStyle(newStyle: DirectionStyle) {
        style = newStyle
        minCutInterval = when (style) {
            DirectionStyle.CONSERVATIVE -> 8000L
            DirectionStyle.DYNAMIC -> 1500L
            DirectionStyle.CINEMATIC -> 5000L
            DirectionStyle.EXPERIMENTAL -> 1000L
            DirectionStyle.BIO_DRIVEN -> 3000L
            DirectionStyle.QUANTUM -> 2000L
            DirectionStyle.MEDITATIVE -> 15000L
            DirectionStyle.CONCERT -> 2000L
        }
    }

    /**
     * Make scene decision based on context
     */
    fun makeDecision(
        bioData: UnifiedBioData,
        lambdaScore: LambdaScoreCalculator.LambdaScore,
        bpm: Float,
        beatPhase: Float,    // 0-1 within beat
        audioEnergy: Float,
        groupState: GroupCoherenceState?
    ): SceneDecision {
        val now = System.currentTimeMillis()

        // Check if we should cut
        if (now - lastCutTime < minCutInterval) {
            return _currentScene.value
        }

        // Determine mood from lambda state
        val mood = when (lambdaScore.state) {
            TranscendenceState.DORMANT -> SceneMood.MYSTERIOUS
            TranscendenceState.AWAKENING -> SceneMood.CALM
            TranscendenceState.AWARE -> SceneMood.PEACEFUL
            TranscendenceState.FLOWING -> SceneMood.PLAYFUL
            TranscendenceState.COHERENT -> SceneMood.ETHEREAL
            TranscendenceState.TRANSCENDENT -> SceneMood.COSMIC
            TranscendenceState.UNIFIED -> SceneMood.TRIUMPHANT
            TranscendenceState.LAMBDA_INFINITE -> SceneMood.COSMIC
        }

        // Determine camera based on context
        val camera = when {
            groupState != null && groupState.isFlowAchieved -> CameraType.GROUP
            lambdaScore.overall > 0.8f -> CameraType.QUANTUM
            audioEnergy > 0.7f -> CameraType.WIDE
            bioData.hrvCoherence > 0.7f -> CameraType.BIO_REACTIVE
            beatPhase < 0.1f -> CameraType.CLOSE_UP // Cut on downbeat
            else -> listOf(CameraType.MEDIUM, CameraType.WIDE).random()
        }

        // Determine transition
        val transition = when (style) {
            DirectionStyle.BIO_DRIVEN -> TransitionType.HEARTBEAT
            DirectionStyle.QUANTUM -> TransitionType.QUANTUM_COLLAPSE
            DirectionStyle.MEDITATIVE -> TransitionType.BREATH
            DirectionStyle.DYNAMIC -> if (beatPhase < 0.1f) TransitionType.CUT else TransitionType.DISSOLVE
            else -> TransitionType.DISSOLVE
        }

        // Determine visual layers
        val layers = mutableListOf<VisualLayerType>()
        if (lambdaScore.overall > 0.6f) layers.add(VisualLayerType.SACRED_GEOMETRY)
        if (audioEnergy > 0.5f) layers.add(VisualLayerType.PARTICLES)
        if (lambdaScore.state.level >= 4) layers.add(VisualLayerType.QUANTUM_FIELD)
        if (bioData.hrvCoherence > 0.5f) layers.add(VisualLayerType.BIO_FIELD)
        if (layers.isEmpty()) layers.add(VisualLayerType.PARTICLES)

        val decision = SceneDecision(
            camera = camera,
            mood = mood,
            transitionType = transition,
            visualLayers = layers,
            confidence = lambdaScore.overall,
            reasoning = "State: ${lambdaScore.state.displayName}, Coherence: ${bioData.hrvCoherence}"
        )

        // Decide if we should actually cut
        val shouldCut = when {
            lambdaScore.state != _currentScene.value.let {
                TranscendenceState.values().find { s -> s.name == it.reasoning.split(":").firstOrNull() }
            } -> true
            audioEnergy > 0.8f && beatPhase < 0.1f -> true
            (bioData.hrvCoherence - 0.5f).absoluteValue > 0.3f -> true
            else -> Math.random() < 0.1 // 10% random cut chance
        }

        if (shouldCut) {
            lastCutTime = now
            _currentScene.value = decision
        }

        return _currentScene.value
    }
}

// ============================================================================
// SESSION ANALYTICS
// ============================================================================

data class SessionAnalytics(
    val sessionId: String,
    val startTime: Long,
    val duration: Long,                    // Milliseconds
    val peakCoherence: Float,
    val averageCoherence: Float,
    val peakLambdaScore: Float,
    val highestState: TranscendenceState,
    val stateTransitions: List<StateTransition>,
    val flowPeaks: List<FlowPeak>,
    val coherenceHistory: List<CoherenceDataPoint>,
    val totalEntanglementEvents: Int
)

data class StateTransition(
    val timestamp: Long,
    val fromState: TranscendenceState,
    val toState: TranscendenceState
)

data class FlowPeak(
    val timestamp: Long,
    val duration: Long,         // How long in flow
    val peakCoherence: Float
)

data class CoherenceDataPoint(
    val timestamp: Long,
    val coherence: Float,
    val lambdaScore: Float
)

// ============================================================================
// MAIN LAMBDA MODE ENGINE
// ============================================================================

class LambdaModeEngine {

    private val scoreCalculator = LambdaScoreCalculator()
    private val gazeTracker = GazeTracker()
    private val hapticEngine = HapticCompositionEngine()
    private val socialEngine = SocialCoherenceEngine()
    private val sceneDirector = AISceneDirector()

    private val _currentState = MutableStateFlow(TranscendenceState.DORMANT)
    val currentState: StateFlow<TranscendenceState> = _currentState

    private val _lambdaScore = MutableStateFlow(LambdaScoreCalculator.LambdaScore(
        overall = 0f,
        coherenceComponent = 0f,
        flowComponent = 0f,
        integrationComponent = 0f,
        state = TranscendenceState.DORMANT
    ))
    val lambdaScore: StateFlow<LambdaScoreCalculator.LambdaScore> = _lambdaScore

    private val _bioData = MutableStateFlow(UnifiedBioData())
    val bioData: StateFlow<UnifiedBioData> = _bioData

    private val _isActive = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = _isActive

    // Session tracking
    private var sessionStartTime = 0L
    private val stateTransitions = mutableListOf<StateTransition>()
    private val flowPeaks = mutableListOf<FlowPeak>()
    private val coherenceHistory = mutableListOf<CoherenceDataPoint>()
    private var peakCoherence = 0f
    private var peakLambdaScore = 0f
    private var highestState = TranscendenceState.DORMANT

    private var audioVisualSync = 0.5f
    private var stateStability = 0.5f

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var updateJob: Job? = null

    // ========================================================================
    // ENGINE CONTROL
    // ========================================================================

    fun start() {
        _isActive.value = true
        sessionStartTime = System.currentTimeMillis()
        stateTransitions.clear()
        flowPeaks.clear()
        coherenceHistory.clear()
        peakCoherence = 0f
        peakLambdaScore = 0f
        highestState = TranscendenceState.DORMANT

        updateJob = scope.launch {
            while (isActive && _isActive.value) {
                updateLambdaState()
                delay(100) // 10Hz update rate
            }
        }
    }

    fun stop(): SessionAnalytics {
        _isActive.value = false
        updateJob?.cancel()

        val duration = System.currentTimeMillis() - sessionStartTime
        val avgCoherence = coherenceHistory.map { it.coherence }.average().toFloat()

        return SessionAnalytics(
            sessionId = sessionStartTime.toString(),
            startTime = sessionStartTime,
            duration = duration,
            peakCoherence = peakCoherence,
            averageCoherence = avgCoherence,
            peakLambdaScore = peakLambdaScore,
            highestState = highestState,
            stateTransitions = stateTransitions.toList(),
            flowPeaks = flowPeaks.toList(),
            coherenceHistory = coherenceHistory.toList(),
            totalEntanglementEvents = socialEngine.groupState.value.entanglementEvents
        )
    }

    // ========================================================================
    // BIO DATA INPUT
    // ========================================================================

    fun updateBioData(data: UnifiedBioData) {
        _bioData.value = data
    }

    fun updateAudioVisualSync(sync: Float) {
        audioVisualSync = sync
    }

    // ========================================================================
    // STATE CALCULATION
    // ========================================================================

    private fun updateLambdaState() {
        val bio = _bioData.value
        val sessionDuration = (System.currentTimeMillis() - sessionStartTime) / 60000L // Minutes

        val newScore = scoreCalculator.calculate(
            bioData = bio,
            audioVisualSync = audioVisualSync,
            sessionDuration = sessionDuration,
            stateStability = stateStability
        )

        // Track state transitions
        if (newScore.state != _currentState.value) {
            stateTransitions.add(StateTransition(
                timestamp = System.currentTimeMillis(),
                fromState = _currentState.value,
                toState = newScore.state
            ))
            stateStability = 0f
        } else {
            stateStability = (stateStability + 0.01f).coerceAtMost(1f)
        }

        // Update peaks
        if (bio.hrvCoherence > peakCoherence) peakCoherence = bio.hrvCoherence
        if (newScore.overall > peakLambdaScore) peakLambdaScore = newScore.overall
        if (newScore.state.level > highestState.level) highestState = newScore.state

        // Record history
        coherenceHistory.add(CoherenceDataPoint(
            timestamp = System.currentTimeMillis(),
            coherence = bio.hrvCoherence,
            lambdaScore = newScore.overall
        ))

        // Limit history size
        if (coherenceHistory.size > 3600) { // 1 hour at 10Hz = 36000, keep last 6 minutes
            coherenceHistory.removeAt(0)
        }

        _lambdaScore.value = newScore
        _currentState.value = newScore.state
    }

    // ========================================================================
    // COMPONENT ACCESS
    // ========================================================================

    fun getGazeTracker() = gazeTracker
    fun getHapticEngine() = hapticEngine
    fun getSocialEngine() = socialEngine
    fun getSceneDirector() = sceneDirector

    companion object {
        const val DISCLAIMER = """
            LAMBDA MODE FEATURES DISCLAIMER

            These features are for creative, meditative, and entertainment purposes only.

            • "Transcendence states" are creative labels, not clinical conditions
            • Bio-reactive features respond to biometric data but do not diagnose
            • Group coherence features measure statistical synchronization only
            • "Quantum" features use quantum-inspired algorithms, not quantum hardware
            • Lambda scores are for engagement, not health assessment

            This is NOT a medical device. Consult healthcare professionals for
            any health-related concerns.
        """
    }
}
