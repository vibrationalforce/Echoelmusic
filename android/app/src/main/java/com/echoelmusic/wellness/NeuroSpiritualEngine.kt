/**
 * NeuroSpiritualEngine.kt
 *
 * Integration of psychosomatic data science including:
 * - FACS (Facial Action Coding System) - Paul Ekman
 * - Polyvagal Theory - Stephen Porges
 * - Embodied Cognition - Varela, Thompson, Rosch
 * - Reich/Lowen Body Segments
 * - HeartMath Heart-Brain Communication
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 *
 * DISCLAIMER: Features are for creative/meditative purposes only.
 * Not a diagnostic or therapeutic tool.
 */
package com.echoelmusic.wellness

import kotlinx.coroutines.flow.*
import kotlin.math.*

// ============================================================================
// CONSCIOUSNESS STATES
// ============================================================================

enum class ConsciousnessState(
    val displayName: String,
    val brainwaveRange: Pair<Float, Float>, // Hz
    val characteristics: String,
    val audioSuggestions: String
) {
    DELTA(
        "Delta",
        0.5f to 4f,
        "Deep sleep, regeneration, unconscious",
        "Deep drones, sub-bass, slow rhythms"
    ),
    THETA(
        "Theta",
        4f to 8f,
        "Light sleep, meditation, creativity, memory",
        "Ambient textures, dream-like sounds"
    ),
    ALPHA(
        "Alpha",
        8f to 12f,
        "Relaxed alertness, calm focus, bridge state",
        "Gentle melodies, nature sounds, 10Hz entrainment"
    ),
    BETA_LOW(
        "Low Beta",
        12f to 15f,
        "Relaxed attention, present awareness",
        "Balanced rhythms, light percussion"
    ),
    BETA_MID(
        "Mid Beta",
        15f to 20f,
        "Active thinking, focused attention",
        "Structured music, clear beats"
    ),
    BETA_HIGH(
        "High Beta",
        20f to 30f,
        "Complex thought, anxiety if prolonged",
        "Complex arrangements, faster tempos"
    ),
    GAMMA(
        "Gamma",
        30f to 100f,
        "Peak awareness, cognition, binding",
        "40Hz binaural, complex harmonics"
    ),
    FLOW(
        "Flow State",
        0f to 0f, // Not a specific brainwave
        "Optimal performance, effortless action",
        "Bio-reactive music matching heart rhythm"
    ),
    TRANSCENDENT(
        "Transcendent",
        0f to 0f,
        "Unity experience, mystical states",
        "Sacred geometry soundscapes, harmonic series"
    ),
    UNITIVE(
        "Unitive Experience",
        0f to 0f,
        "Non-dual awareness, cosmic consciousness",
        "Infinite drones, overtone singing, silence"
    )
}

// ============================================================================
// POLYVAGAL THEORY (Stephen Porges)
// ============================================================================

enum class PolyvagalState(
    val displayName: String,
    val nervousSystemBranch: String,
    val characteristics: String,
    val bodySignals: List<String>,
    val audioRecommendation: String
) {
    VENTRAL_VAGAL(
        "Safe & Social",
        "Ventral Vagal Complex (Social Engagement)",
        "Calm, connected, present, curious",
        listOf(
            "Relaxed facial muscles",
            "Open posture",
            "Melodic voice",
            "Eye contact comfort",
            "Soft belly"
        ),
        "Warm, melodic music with human vocals"
    ),
    SYMPATHETIC(
        "Fight/Flight",
        "Sympathetic Nervous System",
        "Mobilized, alert, anxious, activated",
        listOf(
            "Tense shoulders",
            "Shallow breathing",
            "Scanning environment",
            "Increased heart rate",
            "Tight jaw"
        ),
        "Rhythmic music to discharge energy, then slow to calm"
    ),
    DORSAL_VAGAL(
        "Freeze/Shutdown",
        "Dorsal Vagal Complex",
        "Dissociated, numb, collapsed, immobilized",
        listOf(
            "Flat affect",
            "Slumped posture",
            "Low energy",
            "Difficulty thinking",
            "Disconnection"
        ),
        "Gentle, grounding rhythms, nature sounds, body awareness"
    ),
    SYMPATHETIC_DORSAL(
        "Freeze with Fear",
        "Blended state",
        "Immobilized but terrified",
        listOf(
            "Cannot move but panic inside",
            "Dissociation with fear"
        ),
        "Very slow, safe, predictable music"
    ),
    VENTRAL_SYMPATHETIC(
        "Play/Flow",
        "Blended state",
        "Safe mobilization, joyful activity",
        listOf(
            "Playful movement",
            "Laughter",
            "Dance",
            "Creative expression"
        ),
        "Upbeat, playful music with safe container"
    )
}

// ============================================================================
// FACIAL ACTION CODING SYSTEM (FACS)
// ============================================================================

/**
 * FACS Action Units (Ekman & Friesen)
 */
enum class FACSActionUnit(
    val code: String,
    val muscle: String,
    val description: String
) {
    AU1("AU1", "Frontalis (medial)", "Inner Brow Raise"),
    AU2("AU2", "Frontalis (lateral)", "Outer Brow Raise"),
    AU4("AU4", "Depressor glabellae", "Brow Lower/Furrow"),
    AU5("AU5", "Levator palpebrae", "Upper Lid Raise"),
    AU6("AU6", "Orbicularis oculi", "Cheek Raise (Duchenne)"),
    AU7("AU7", "Orbicularis oculi", "Lid Tighten"),
    AU9("AU9", "Levator labii superioris", "Nose Wrinkle"),
    AU10("AU10", "Levator labii superioris", "Upper Lip Raise"),
    AU12("AU12", "Zygomaticus major", "Lip Corner Pull (Smile)"),
    AU14("AU14", "Buccinator", "Dimpler"),
    AU15("AU15", "Depressor anguli oris", "Lip Corner Depress"),
    AU17("AU17", "Mentalis", "Chin Raise"),
    AU20("AU20", "Risorius", "Lip Stretch"),
    AU23("AU23", "Orbicularis oris", "Lip Tighten"),
    AU24("AU24", "Orbicularis oris", "Lip Press"),
    AU25("AU25", "Depressor labii", "Lips Part"),
    AU26("AU26", "Masseter", "Jaw Drop"),
    AU27("AU27", "Pterygoids", "Mouth Stretch"),
    AU43("AU43", "Relaxation of levator palpebrae", "Eyes Closed"),
    AU45("AU45", "Orbicularis oculi", "Blink")
}

/**
 * Primary emotions (Ekman model)
 */
enum class PrimaryEmotion(
    val displayName: String,
    val facsPattern: List<FACSActionUnit>,
    val audioMapping: String
) {
    JOY(
        "Joy/Happiness",
        listOf(FACSActionUnit.AU6, FACSActionUnit.AU12),
        "Major keys, bright timbre, upward melodic motion"
    ),
    SADNESS(
        "Sadness",
        listOf(FACSActionUnit.AU1, FACSActionUnit.AU4, FACSActionUnit.AU15),
        "Minor keys, slow tempo, downward motion, reverb"
    ),
    ANGER(
        "Anger",
        listOf(FACSActionUnit.AU4, FACSActionUnit.AU5, FACSActionUnit.AU7, FACSActionUnit.AU23),
        "Distortion, aggressive rhythm, dissonance"
    ),
    FEAR(
        "Fear",
        listOf(FACSActionUnit.AU1, FACSActionUnit.AU2, FACSActionUnit.AU4, FACSActionUnit.AU5, FACSActionUnit.AU20, FACSActionUnit.AU26),
        "High frequency tension, unpredictable rhythm, suspense"
    ),
    DISGUST(
        "Disgust",
        listOf(FACSActionUnit.AU9, FACSActionUnit.AU15, FACSActionUnit.AU17),
        "Dissonant clusters, harsh timbres"
    ),
    SURPRISE(
        "Surprise",
        listOf(FACSActionUnit.AU1, FACSActionUnit.AU2, FACSActionUnit.AU5, FACSActionUnit.AU26),
        "Sudden dynamic changes, unexpected harmonies"
    ),
    CONTEMPT(
        "Contempt",
        listOf(FACSActionUnit.AU12, FACSActionUnit.AU14), // Unilateral
        "Asymmetric patterns, subtle tension"
    )
}

/**
 * Complex emotional states
 */
enum class ComplexEmotionalState(
    val displayName: String,
    val description: String,
    val facsIndicators: List<FACSActionUnit>
) {
    ENGAGEMENT(
        "Engagement",
        "Active interest and involvement",
        listOf(FACSActionUnit.AU1, FACSActionUnit.AU2, FACSActionUnit.AU5)
    ),
    CONFUSION(
        "Confusion",
        "Uncertainty and cognitive effort",
        listOf(FACSActionUnit.AU4, FACSActionUnit.AU7)
    ),
    FRUSTRATION(
        "Frustration",
        "Blocked goal pursuit",
        listOf(FACSActionUnit.AU4, FACSActionUnit.AU17, FACSActionUnit.AU24)
    ),
    DETERMINATION(
        "Determination",
        "Focused resolve",
        listOf(FACSActionUnit.AU4, FACSActionUnit.AU7, FACSActionUnit.AU24)
    ),
    SERENITY(
        "Serenity",
        "Deep calm and peace",
        listOf(FACSActionUnit.AU12, FACSActionUnit.AU43) // Slight smile, soft eyes
    ),
    AWE(
        "Awe",
        "Vastness and wonder",
        listOf(FACSActionUnit.AU1, FACSActionUnit.AU2, FACSActionUnit.AU5, FACSActionUnit.AU25, FACSActionUnit.AU26)
    )
}

// ============================================================================
// DUCHENNE SMILE DETECTION
// ============================================================================

data class SmileAnalysis(
    val isDuchenneSmile: Boolean,      // True smile with AU6+AU12
    val isSocialSmile: Boolean,        // AU12 only
    val smileIntensity: Float,         // 0-1
    val genuinenessScore: Float,       // 0-1
    val asymmetryScore: Float          // 0 = symmetric, 1 = asymmetric
)

class DuchenneSmileDetector {
    /**
     * Analyze smile authenticity
     * Duchenne smile: AU6 (cheek raise) + AU12 (lip corner pull)
     * Social smile: AU12 only
     */
    fun analyzeSmile(
        au6Intensity: Float,    // Cheek raise (crow's feet)
        au12Intensity: Float,   // Lip corner pull
        leftRightAsymmetry: Float = 0f
    ): SmileAnalysis {
        val hasAu6 = au6Intensity > 0.3f
        val hasAu12 = au12Intensity > 0.3f

        val isDuchenne = hasAu6 && hasAu12
        val isSocial = hasAu12 && !hasAu6

        val genuineness = if (isDuchenne) {
            (au6Intensity + au12Intensity) / 2f
        } else if (isSocial) {
            au12Intensity * 0.5f // Social smiles are less "genuine"
        } else {
            0f
        }

        return SmileAnalysis(
            isDuchenneSmile = isDuchenne,
            isSocialSmile = isSocial,
            smileIntensity = au12Intensity,
            genuinenessScore = genuineness,
            asymmetryScore = leftRightAsymmetry
        )
    }
}

// ============================================================================
// GESTURE ANALYSIS
// ============================================================================

enum class GestureType(
    val displayName: String,
    val description: String,
    val psychologicalMeaning: String
) {
    OPEN_PALMS(
        "Open Palms",
        "Palms visible, facing up or outward",
        "Openness, honesty, receptivity"
    ),
    CLOSED_FISTS(
        "Closed Fists",
        "Hands clenched",
        "Tension, determination, anger"
    ),
    STEEPLING(
        "Steepling",
        "Fingertips touching, forming a peak",
        "Confidence, authority, contemplation"
    ),
    SELF_TOUCH(
        "Self-Touch",
        "Touching face, neck, arms",
        "Self-soothing, anxiety, deception"
    ),
    HEART_CENTERED(
        "Heart-Centered",
        "Hands over heart area",
        "Sincerity, emotional connection, gratitude"
    ),
    EXPANSIVE(
        "Expansive",
        "Wide arm movements, taking up space",
        "Confidence, power, openness"
    ),
    CONTRACTED(
        "Contracted",
        "Arms close to body, minimal movement",
        "Defensiveness, insecurity, withdrawal"
    ),
    RHYTHMIC(
        "Rhythmic",
        "Regular, pulsing movements",
        "Engagement, emphasis, flow state"
    )
}

data class HandPosition(
    val x: Float,           // Normalized 0-1
    val y: Float,           // Normalized 0-1
    val z: Float,           // Depth
    val openness: Float,    // 0 = fist, 1 = open palm
    val velocity: Float     // Movement speed
)

data class GestureAnalysis(
    val dominantGesture: GestureType,
    val handOpenness: Float,
    val movementEnergy: Float,
    val heartCenterDistance: Float, // Distance from chest
    val symmetry: Float
)

// ============================================================================
// REICH/LOWEN BODY SEGMENTS
// ============================================================================

enum class BodySegment(
    val displayName: String,
    val location: String,
    val heldEmotions: List<String>,
    val releaseSignals: List<String>
) {
    OCULAR(
        "Ocular Segment",
        "Eyes, forehead",
        listOf("Fear", "Terror", "Dissociation"),
        listOf("Widening eyes", "Crying", "Eye contact")
    ),
    ORAL(
        "Oral Segment",
        "Mouth, jaw, throat",
        listOf("Grief", "Anger", "Longing", "Sucking reflex"),
        listOf("Crying", "Screaming", "Biting motion", "Deep sighs")
    ),
    CERVICAL(
        "Cervical Segment",
        "Neck, back of head",
        listOf("Rage", "Crying", "Pride"),
        listOf("Neck stretching", "Looking up", "Head shaking")
    ),
    THORACIC(
        "Thoracic Segment",
        "Chest, upper back, arms, hands",
        listOf("Heartbreak", "Longing", "Reaching out"),
        listOf("Sobbing", "Reaching gestures", "Deep breathing")
    ),
    DIAPHRAGM(
        "Diaphragmatic Segment",
        "Diaphragm, solar plexus",
        listOf("Rage", "Fear", "Anxiety"),
        listOf("Deep exhale", "Gagging reflex", "Full breath")
    ),
    ABDOMINAL(
        "Abdominal Segment",
        "Belly, lower back",
        listOf("Fear", "Spitefulness", "Nastiness"),
        listOf("Softening belly", "Gurgling", "Deeper breath")
    ),
    PELVIC(
        "Pelvic Segment",
        "Pelvis, genitals, legs, feet",
        listOf("Rage", "Pleasure anxiety", "Grounding"),
        listOf("Pelvic movement", "Grounding through feet", "Pleasurable sensations")
    )
}

data class BodySegmentState(
    val segment: BodySegment,
    val tensionLevel: Float,        // 0-1
    val breathingAccess: Float,     // 0-1 (how much breath reaches this area)
    val movementFluidity: Float,    // 0-1
    val energyFlow: Float           // 0-1
)

// ============================================================================
// PSYCHOSOMATIC STATE INTEGRATION
// ============================================================================

data class PsychosomaticState(
    // Facial/Emotional
    val primaryEmotion: PrimaryEmotion?,
    val smileAnalysis: SmileAnalysis?,
    val emotionalValence: Float,        // -1 (negative) to 1 (positive)
    val emotionalArousal: Float,        // 0 (calm) to 1 (activated)

    // Polyvagal
    val polyvagalState: PolyvagalState,
    val vagalTone: Float,               // 0-1 (HRV-based)

    // Consciousness
    val consciousnessState: ConsciousnessState,

    // Body
    val bodySegmentStates: List<BodySegmentState>,
    val overallGrounding: Float,        // 0-1
    val breathingDepth: Float,          // 0-1

    // Gesture
    val gestureAnalysis: GestureAnalysis?,

    // Composite scores
    val wellbeingScore: Float,          // 0-100
    val presenceScore: Float,           // 0-100
    val embodimentScore: Float,         // 0-100
    val connectionScore: Float          // 0-100
)

// ============================================================================
// MAIN NEUROSPIRITUAL ENGINE
// ============================================================================

class NeuroSpiritualEngine {

    private val duchenneDetector = DuchenneSmileDetector()

    private val _currentState = MutableStateFlow<PsychosomaticState?>(null)
    val currentState: StateFlow<PsychosomaticState?> = _currentState

    private val _consciousnessState = MutableStateFlow(ConsciousnessState.ALPHA)
    val consciousnessState: StateFlow<ConsciousnessState> = _consciousnessState

    private val _polyvagalState = MutableStateFlow(PolyvagalState.VENTRAL_VAGAL)
    val polyvagalState: StateFlow<PolyvagalState> = _polyvagalState

    // ========================================================================
    // FACIAL EXPRESSION ANALYSIS
    // ========================================================================

    /**
     * Analyze facial action units and detect emotion
     */
    fun analyzeFacialExpression(
        actionUnits: Map<FACSActionUnit, Float> // AU code to intensity (0-1)
    ): PrimaryEmotion? {
        var bestMatch: PrimaryEmotion? = null
        var bestScore = 0f

        for (emotion in PrimaryEmotion.values()) {
            var score = 0f
            var matchCount = 0

            for (requiredAU in emotion.facsPattern) {
                val intensity = actionUnits[requiredAU] ?: 0f
                if (intensity > 0.3f) {
                    score += intensity
                    matchCount++
                }
            }

            // Normalize by pattern size
            val normalizedScore = if (emotion.facsPattern.isNotEmpty()) {
                score / emotion.facsPattern.size
            } else 0f

            // Require at least half the AUs present
            if (matchCount >= emotion.facsPattern.size / 2 && normalizedScore > bestScore) {
                bestScore = normalizedScore
                bestMatch = emotion
            }
        }

        return bestMatch
    }

    /**
     * Detect Duchenne (genuine) vs social smile
     */
    fun analyzeSmile(au6: Float, au12: Float, asymmetry: Float = 0f): SmileAnalysis {
        return duchenneDetector.analyzeSmile(au6, au12, asymmetry)
    }

    // ========================================================================
    // POLYVAGAL STATE DETECTION
    // ========================================================================

    /**
     * Estimate polyvagal state from HRV and behavioral cues
     */
    fun detectPolyvagalState(
        hrvCoherence: Float,
        heartRateVariability: Float,
        facialTension: Float,
        breathingRate: Float,
        postureOpenness: Float
    ): PolyvagalState {
        // Ventral vagal indicators
        val ventralScore = (hrvCoherence * 0.4f +
                (1f - facialTension) * 0.2f +
                postureOpenness * 0.2f +
                (if (breathingRate in 4f..8f) 0.2f else 0f))

        // Sympathetic indicators
        val sympatheticScore = (facialTension * 0.3f +
                (if (breathingRate > 15f) 0.3f else 0f) +
                (if (heartRateVariability < 30f) 0.2f else 0f) +
                (1f - postureOpenness) * 0.2f)

        // Dorsal indicators
        val dorsalScore = ((if (breathingRate < 8f && hrvCoherence < 0.3f) 0.4f else 0f) +
                (if (heartRateVariability < 20f) 0.3f else 0f) +
                (1f - postureOpenness) * 0.3f)

        // Determine state
        val state = when {
            ventralScore > 0.6f && sympatheticScore > 0.3f -> PolyvagalState.VENTRAL_SYMPATHETIC
            ventralScore > 0.5f -> PolyvagalState.VENTRAL_VAGAL
            dorsalScore > 0.5f && sympatheticScore > 0.3f -> PolyvagalState.SYMPATHETIC_DORSAL
            dorsalScore > 0.5f -> PolyvagalState.DORSAL_VAGAL
            sympatheticScore > 0.4f -> PolyvagalState.SYMPATHETIC
            else -> PolyvagalState.VENTRAL_VAGAL
        }

        _polyvagalState.value = state
        return state
    }

    // ========================================================================
    // CONSCIOUSNESS STATE MAPPING
    // ========================================================================

    /**
     * Estimate consciousness state from EEG-like indicators and behavior
     */
    fun detectConsciousnessState(
        hrvCoherence: Float,
        focusLevel: Float,
        relaxationLevel: Float,
        movementAmount: Float
    ): ConsciousnessState {
        val state = when {
            hrvCoherence > 0.8f && focusLevel > 0.7f && movementAmount > 0.3f ->
                ConsciousnessState.FLOW
            hrvCoherence > 0.9f && relaxationLevel > 0.8f ->
                ConsciousnessState.TRANSCENDENT
            relaxationLevel > 0.8f && focusLevel < 0.3f ->
                ConsciousnessState.THETA
            relaxationLevel > 0.6f && focusLevel < 0.5f ->
                ConsciousnessState.ALPHA
            focusLevel > 0.7f && relaxationLevel > 0.4f ->
                ConsciousnessState.BETA_LOW
            focusLevel > 0.8f ->
                ConsciousnessState.BETA_MID
            focusLevel > 0.9f && relaxationLevel < 0.3f ->
                ConsciousnessState.BETA_HIGH
            else -> ConsciousnessState.ALPHA
        }

        _consciousnessState.value = state
        return state
    }

    // ========================================================================
    // GESTURE ANALYSIS
    // ========================================================================

    fun analyzeGestures(
        leftHand: HandPosition?,
        rightHand: HandPosition?
    ): GestureAnalysis {
        val avgOpenness = listOfNotNull(leftHand?.openness, rightHand?.openness)
            .average().toFloat()

        val avgVelocity = listOfNotNull(leftHand?.velocity, rightHand?.velocity)
            .average().toFloat()

        // Calculate heart center distance (assuming y=0.5 is heart level)
        val heartCenterDist = listOfNotNull(leftHand, rightHand).map { hand ->
            sqrt((hand.x - 0.5f).pow(2) + (hand.y - 0.5f).pow(2))
        }.average().toFloat()

        // Symmetry
        val symmetry = if (leftHand != null && rightHand != null) {
            1f - abs(leftHand.x - (1f - rightHand.x))
        } else 0.5f

        // Determine dominant gesture
        val gesture = when {
            avgOpenness > 0.8f -> GestureType.OPEN_PALMS
            avgOpenness < 0.2f -> GestureType.CLOSED_FISTS
            heartCenterDist < 0.2f && avgOpenness > 0.5f -> GestureType.HEART_CENTERED
            avgVelocity > 0.5f && symmetry > 0.7f -> GestureType.EXPANSIVE
            avgVelocity < 0.2f -> GestureType.CONTRACTED
            avgVelocity > 0.3f -> GestureType.RHYTHMIC
            else -> GestureType.SELF_TOUCH
        }

        return GestureAnalysis(
            dominantGesture = gesture,
            handOpenness = avgOpenness,
            movementEnergy = avgVelocity,
            heartCenterDistance = heartCenterDist,
            symmetry = symmetry
        )
    }

    // ========================================================================
    // BODY SEGMENT ANALYSIS
    // ========================================================================

    fun analyzeBodySegments(
        breathingDepth: Float,
        shoulderTension: Float,
        jawTension: Float,
        bellyRelaxation: Float,
        pelvicMobility: Float
    ): List<BodySegmentState> {
        return listOf(
            BodySegmentState(
                segment = BodySegment.OCULAR,
                tensionLevel = 0.3f, // Would need eye tracking data
                breathingAccess = breathingDepth * 0.5f,
                movementFluidity = 0.7f,
                energyFlow = 0.6f
            ),
            BodySegmentState(
                segment = BodySegment.ORAL,
                tensionLevel = jawTension,
                breathingAccess = breathingDepth * 0.7f,
                movementFluidity = 1f - jawTension,
                energyFlow = 1f - jawTension * 0.5f
            ),
            BodySegmentState(
                segment = BodySegment.CERVICAL,
                tensionLevel = shoulderTension * 0.8f,
                breathingAccess = breathingDepth * 0.6f,
                movementFluidity = 1f - shoulderTension,
                energyFlow = 1f - shoulderTension * 0.5f
            ),
            BodySegmentState(
                segment = BodySegment.THORACIC,
                tensionLevel = shoulderTension,
                breathingAccess = breathingDepth,
                movementFluidity = breathingDepth,
                energyFlow = breathingDepth * 0.8f
            ),
            BodySegmentState(
                segment = BodySegment.DIAPHRAGM,
                tensionLevel = 1f - breathingDepth,
                breathingAccess = breathingDepth,
                movementFluidity = breathingDepth,
                energyFlow = breathingDepth
            ),
            BodySegmentState(
                segment = BodySegment.ABDOMINAL,
                tensionLevel = 1f - bellyRelaxation,
                breathingAccess = breathingDepth * bellyRelaxation,
                movementFluidity = bellyRelaxation,
                energyFlow = bellyRelaxation * 0.9f
            ),
            BodySegmentState(
                segment = BodySegment.PELVIC,
                tensionLevel = 1f - pelvicMobility,
                breathingAccess = breathingDepth * pelvicMobility * 0.5f,
                movementFluidity = pelvicMobility,
                energyFlow = pelvicMobility
            )
        )
    }

    // ========================================================================
    // INTEGRATED STATE UPDATE
    // ========================================================================

    fun updateIntegratedState(
        // Facial
        facialActionUnits: Map<FACSActionUnit, Float>?,

        // Biometric
        hrvCoherence: Float,
        heartRateVariability: Float,
        breathingRate: Float,
        breathingDepth: Float,

        // Body
        shoulderTension: Float = 0.3f,
        jawTension: Float = 0.3f,
        bellyRelaxation: Float = 0.7f,
        pelvicMobility: Float = 0.6f,
        postureOpenness: Float = 0.7f,

        // Hands
        leftHand: HandPosition? = null,
        rightHand: HandPosition? = null,

        // Activity
        focusLevel: Float = 0.5f,
        movementAmount: Float = 0.3f
    ) {
        // Analyze components
        val emotion = facialActionUnits?.let { analyzeFacialExpression(it) }
        val smile = facialActionUnits?.let {
            analyzeSmile(
                it[FACSActionUnit.AU6] ?: 0f,
                it[FACSActionUnit.AU12] ?: 0f
            )
        }
        val polyvagal = detectPolyvagalState(
            hrvCoherence, heartRateVariability, jawTension, breathingRate, postureOpenness
        )
        val consciousness = detectConsciousnessState(
            hrvCoherence, focusLevel, 1f - jawTension, movementAmount
        )
        val gesture = analyzeGestures(leftHand, rightHand)
        val bodySegments = analyzeBodySegments(
            breathingDepth, shoulderTension, jawTension, bellyRelaxation, pelvicMobility
        )

        // Calculate composite scores
        val wellbeing = calculateWellbeingScore(
            hrvCoherence, polyvagal, emotion, smile
        )
        val presence = calculatePresenceScore(
            consciousness, focusLevel, breathingDepth
        )
        val embodiment = calculateEmbodimentScore(bodySegments)
        val connection = calculateConnectionScore(
            polyvagal, gesture, smile
        )

        // Emotional valence and arousal
        val valence = calculateEmotionalValence(emotion, smile)
        val arousal = calculateEmotionalArousal(heartRateVariability, movementAmount)

        _currentState.value = PsychosomaticState(
            primaryEmotion = emotion,
            smileAnalysis = smile,
            emotionalValence = valence,
            emotionalArousal = arousal,
            polyvagalState = polyvagal,
            vagalTone = hrvCoherence,
            consciousnessState = consciousness,
            bodySegmentStates = bodySegments,
            overallGrounding = (bellyRelaxation + pelvicMobility) / 2f,
            breathingDepth = breathingDepth,
            gestureAnalysis = gesture,
            wellbeingScore = wellbeing,
            presenceScore = presence,
            embodimentScore = embodiment,
            connectionScore = connection
        )
    }

    private fun calculateWellbeingScore(
        coherence: Float,
        polyvagal: PolyvagalState,
        emotion: PrimaryEmotion?,
        smile: SmileAnalysis?
    ): Float {
        var score = 50f

        // Coherence contribution
        score += coherence * 20f

        // Polyvagal state
        score += when (polyvagal) {
            PolyvagalState.VENTRAL_VAGAL -> 15f
            PolyvagalState.VENTRAL_SYMPATHETIC -> 10f
            PolyvagalState.SYMPATHETIC -> -5f
            PolyvagalState.DORSAL_VAGAL -> -10f
            PolyvagalState.SYMPATHETIC_DORSAL -> -15f
        }

        // Positive emotions
        if (emotion == PrimaryEmotion.JOY) score += 10f

        // Genuine smile
        if (smile?.isDuchenneSmile == true) score += 5f

        return score.coerceIn(0f, 100f)
    }

    private fun calculatePresenceScore(
        consciousness: ConsciousnessState,
        focus: Float,
        breathingDepth: Float
    ): Float {
        var score = 50f

        score += when (consciousness) {
            ConsciousnessState.FLOW -> 30f
            ConsciousnessState.ALPHA -> 20f
            ConsciousnessState.TRANSCENDENT -> 25f
            ConsciousnessState.THETA -> 15f
            else -> 0f
        }

        score += focus * 10f
        score += breathingDepth * 10f

        return score.coerceIn(0f, 100f)
    }

    private fun calculateEmbodimentScore(segments: List<BodySegmentState>): Float {
        val avgFlow = segments.map { it.energyFlow }.average().toFloat()
        val avgFluidity = segments.map { it.movementFluidity }.average().toFloat()
        val avgBreathAccess = segments.map { it.breathingAccess }.average().toFloat()

        return ((avgFlow + avgFluidity + avgBreathAccess) / 3f * 100f).coerceIn(0f, 100f)
    }

    private fun calculateConnectionScore(
        polyvagal: PolyvagalState,
        gesture: GestureAnalysis,
        smile: SmileAnalysis?
    ): Float {
        var score = 50f

        score += when (polyvagal) {
            PolyvagalState.VENTRAL_VAGAL -> 25f
            PolyvagalState.VENTRAL_SYMPATHETIC -> 20f
            else -> 0f
        }

        if (gesture.dominantGesture == GestureType.OPEN_PALMS ||
            gesture.dominantGesture == GestureType.HEART_CENTERED) {
            score += 15f
        }

        if (smile?.isDuchenneSmile == true) score += 10f

        return score.coerceIn(0f, 100f)
    }

    private fun calculateEmotionalValence(emotion: PrimaryEmotion?, smile: SmileAnalysis?): Float {
        var valence = 0f

        valence += when (emotion) {
            PrimaryEmotion.JOY -> 0.8f
            PrimaryEmotion.SURPRISE -> 0.3f
            PrimaryEmotion.SADNESS -> -0.6f
            PrimaryEmotion.ANGER -> -0.7f
            PrimaryEmotion.FEAR -> -0.8f
            PrimaryEmotion.DISGUST -> -0.5f
            PrimaryEmotion.CONTEMPT -> -0.3f
            null -> 0f
        }

        if (smile?.isDuchenneSmile == true) valence += 0.2f

        return valence.coerceIn(-1f, 1f)
    }

    private fun calculateEmotionalArousal(hrv: Float, movement: Float): Float {
        // Lower HRV = higher arousal, more movement = higher arousal
        val hrvArousal = 1f - (hrv / 100f).coerceIn(0f, 1f)
        return ((hrvArousal + movement) / 2f).coerceIn(0f, 1f)
    }

    companion object {
        const val DISCLAIMER = """
            NEUROSPIRITUAL FEATURES DISCLAIMER

            These features are for creative and meditative purposes only.

            • This is NOT a diagnostic tool
            • This is NOT a therapeutic intervention
            • Emotional/consciousness state detection is approximate
            • Does not replace professional mental health support
            • Based on research but not clinically validated

            If you are experiencing mental health difficulties, please
            consult a qualified healthcare professional.
        """
    }
}
