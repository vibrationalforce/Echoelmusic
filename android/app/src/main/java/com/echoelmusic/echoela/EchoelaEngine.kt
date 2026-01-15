/**
 * EchoelaEngine.kt
 * Echoelmusic - Inclusive Intelligent Guide System (Android)
 *
 * Echoela is a calm, non-judgmental guide that:
 * - Adapts to user skill level and confidence
 * - Detects confusion and offers help without pressure
 * - Supports all accessibility profiles
 * - Is always optional and dismissible
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.echoela

import android.content.Context
import android.content.SharedPreferences
import android.os.VibrationEffect
import android.os.Vibrator
import android.speech.tts.TextToSpeech
import android.view.accessibility.AccessibilityManager
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.util.*

/**
 * Core engine for Echoela inclusive guide
 */
class EchoelaEngine private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var instance: EchoelaEngine? = null

        fun getInstance(context: Context): EchoelaEngine {
            return instance ?: synchronized(this) {
                instance ?: EchoelaEngine(context.applicationContext).also { instance = it }
            }
        }

        private const val PREFS_NAME = "echoela_prefs"
        private const val KEY_IS_ENABLED = "is_enabled"
        private const val KEY_SHOW_HINTS = "show_hints"
        private const val KEY_HAS_SEEN_WELCOME = "has_seen_welcome"
        private const val KEY_TEXT_SIZE = "text_size"
        private const val KEY_USE_CALM_COLORS = "use_calm_colors"
        private const val KEY_REDUCE_ANIMATIONS = "reduce_animations"
        private const val KEY_VOICE_GUIDANCE = "voice_guidance"
        private const val KEY_SKILL_LEVEL = "skill_level"
        private const val KEY_CONFIDENCE = "confidence"
        private const val KEY_GUIDANCE_DENSITY = "guidance_density"
        private const val KEY_COMPLETED_TOPICS = "completed_topics"
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // State flows
    private val _isActive = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = _isActive.asStateFlow()

    private val _currentContext = MutableStateFlow<GuidanceContext?>(null)
    val currentContext: StateFlow<GuidanceContext?> = _currentContext.asStateFlow()

    private val _skillLevel = MutableStateFlow(0.5f)
    val skillLevel: StateFlow<Float> = _skillLevel.asStateFlow()

    private val _confidenceScore = MutableStateFlow(0.5f)
    val confidenceScore: StateFlow<Float> = _confidenceScore.asStateFlow()

    private val _guidanceDensity = MutableStateFlow(0.5f)
    val guidanceDensity: StateFlow<Float> = _guidanceDensity.asStateFlow()

    private val _currentHint = MutableStateFlow<GuidanceHint?>(null)
    val currentHint: StateFlow<GuidanceHint?> = _currentHint.asStateFlow()

    private val _pendingHelpOffer = MutableStateFlow<HelpOffer?>(null)
    val pendingHelpOffer: StateFlow<HelpOffer?> = _pendingHelpOffer.asStateFlow()

    private val _userSeemsConfused = MutableStateFlow(false)
    val userSeemsConfused: StateFlow<Boolean> = _userSeemsConfused.asStateFlow()

    private val _completedTopics = MutableStateFlow<Set<GuidanceTopic>>(emptySet())
    val completedTopics: StateFlow<Set<GuidanceTopic>> = _completedTopics.asStateFlow()

    // Preferences
    private val _preferences = MutableStateFlow(loadPreferences())
    val preferences: StateFlow<EchoelaPreferences> = _preferences.asStateFlow()

    // Internal state
    private val interactionHistory = mutableListOf<InteractionEvent>()
    private var lastInteractionTime = System.currentTimeMillis()
    private var hesitationJob: Job? = null

    // Text-to-speech
    private var tts: TextToSpeech? = null

    // Constants
    private val hesitationThresholdMs = 5000L
    private val confusionThreshold = 3
    private val maxHistorySize = 100

    init {
        loadProgress()
        initTts()
    }

    private fun initTts() {
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.getDefault()
            }
        }
    }

    // ========================================================================
    // Activation
    // ========================================================================

    fun activate() {
        if (!_preferences.value.isEnabled) return

        _isActive.value = true
        startHesitationMonitoring()

        if (!_preferences.value.hasSeenWelcome) {
            showWelcome()
        }
    }

    fun deactivate() {
        _isActive.value = false
        _currentHint.value = null
        _pendingHelpOffer.value = null
        hesitationJob?.cancel()
    }

    fun pause() {
        _isActive.value = false
        hesitationJob?.cancel()
    }

    fun resume() {
        if (_preferences.value.isEnabled) {
            _isActive.value = true
            startHesitationMonitoring()
        }
    }

    // ========================================================================
    // Context Management
    // ========================================================================

    fun enterContext(context: GuidanceContext) {
        _currentContext.value = context

        if (shouldOfferHint(context)) {
            offerContextualHint(context)
        }
    }

    fun exitContext() {
        _currentContext.value = null
        _currentHint.value = null
    }

    // ========================================================================
    // Interaction Tracking
    // ========================================================================

    fun recordInteraction(event: InteractionEvent) {
        lastInteractionTime = System.currentTimeMillis()
        _userSeemsConfused.value = false

        interactionHistory.add(event)
        if (interactionHistory.size > maxHistorySize) {
            interactionHistory.removeAt(0)
        }

        analyzeInteractionPatterns()

        if (event.wasSuccessful) {
            adjustSkillLevel(0.01f)
            adjustConfidence(0.02f)
        } else {
            adjustConfidence(-0.01f)
        }
    }

    fun recordError(error: UserError) {
        val event = InteractionEvent(
            type = InteractionType.ERROR,
            context = _currentContext.value,
            wasSuccessful = false,
            errorType = error
        )
        recordInteraction(event)
        checkForConfusion()
    }

    // ========================================================================
    // Adaptive Guidance
    // ========================================================================

    private fun analyzeInteractionPatterns() {
        val recentErrors = interactionHistory.takeLast(10).filter { it.errorType != null }

        if (recentErrors.size >= confusionThreshold) {
            _userSeemsConfused.value = true
            offerHelp(HelpOfferReason.REPEATED_ERRORS)
        }

        // Adjust guidance density
        val skill = _skillLevel.value
        if (skill > 0.7f) {
            _guidanceDensity.value = maxOf(0.2f, _guidanceDensity.value - 0.1f)
        } else if (skill < 0.3f) {
            _guidanceDensity.value = minOf(0.8f, _guidanceDensity.value + 0.1f)
        }
    }

    private fun adjustSkillLevel(delta: Float) {
        _skillLevel.value = (_skillLevel.value + delta).coerceIn(0f, 1f)
    }

    private fun adjustConfidence(delta: Float) {
        _confidenceScore.value = (_confidenceScore.value + delta).coerceIn(0f, 1f)
    }

    // ========================================================================
    // Hesitation Detection
    // ========================================================================

    private fun startHesitationMonitoring() {
        hesitationJob?.cancel()
        hesitationJob = scope.launch {
            while (isActive) {
                delay(1000)
                checkForHesitation()
            }
        }
    }

    private fun checkForHesitation() {
        val timeSinceLastInteraction = System.currentTimeMillis() - lastInteractionTime

        if (timeSinceLastInteraction > hesitationThresholdMs && _currentContext.value != null) {
            if (_pendingHelpOffer.value == null && !_userSeemsConfused.value) {
                offerHelp(HelpOfferReason.HESITATION)
            }
        }
    }

    private fun checkForConfusion() {
        val contextId = _currentContext.value?.id
        val recentContextErrors = interactionHistory.takeLast(5).filter {
            it.context?.id == contextId && it.errorType != null
        }

        if (recentContextErrors.size >= 2) {
            _userSeemsConfused.value = true
            offerHelp(HelpOfferReason.REPEATED_ERRORS)
        }
    }

    // ========================================================================
    // Help Offers
    // ========================================================================

    private fun offerHelp(reason: HelpOfferReason) {
        if (!_preferences.value.isEnabled || !_isActive.value) return
        if (_pendingHelpOffer.value != null) return

        val offer = HelpOffer(
            reason = reason,
            context = _currentContext.value,
            message = generateHelpMessage(reason),
            dismissable = true,
            timestamp = System.currentTimeMillis()
        )

        _pendingHelpOffer.value = offer

        // Voice announcement if enabled
        if (_preferences.value.voiceGuidance) {
            speak(offer.message)
        }
    }

    private fun generateHelpMessage(reason: HelpOfferReason): String {
        val messages = when (reason) {
            HelpOfferReason.HESITATION -> listOf(
                "Take your time. Would you like some guidance?",
                "No rush. I'm here if you need a hint.",
                "Whenever you're ready. Need any help?"
            )
            HelpOfferReason.REPEATED_ERRORS -> listOf(
                "That can be tricky. Would you like me to explain?",
                "Let me help clarify this for you.",
                "This part takes practice. Want some tips?"
            )
            HelpOfferReason.FIRST_TIME -> listOf(
                "This is new. Would you like a quick overview?",
                "First time here? I can show you around.",
                "Let me introduce you to this feature."
            )
            HelpOfferReason.USER_REQUESTED -> listOf("How can I help you?")
        }
        return messages.random()
    }

    fun acceptHelp() {
        val offer = _pendingHelpOffer.value ?: return

        offer.context?.let { showGuidance(it) } ?: showGeneralHelp()
        _pendingHelpOffer.value = null
    }

    fun dismissHelp() {
        _pendingHelpOffer.value = null
        _userSeemsConfused.value = false
        lastInteractionTime = System.currentTimeMillis()
    }

    // ========================================================================
    // Hints
    // ========================================================================

    private fun shouldOfferHint(context: GuidanceContext): Boolean {
        if (_completedTopics.value.contains(context.topic) && _skillLevel.value > 0.6f) {
            return false
        }
        if (_guidanceDensity.value < 0.3f) {
            return false
        }
        return _preferences.value.showHints
    }

    private fun offerContextualHint(context: GuidanceContext) {
        val hint = context.hints.firstOrNull() ?: return
        _currentHint.value = hint

        // Auto-dismiss after delay
        scope.launch {
            delay(10000)
            if (_currentHint.value?.id == hint.id) {
                _currentHint.value = null
            }
        }
    }

    fun dismissHint() {
        _currentHint.value = null
    }

    fun expandHint() {
        _currentHint.value?.let { hint ->
            _currentHint.value = hint.copy(isExpanded = true)
        }
    }

    // ========================================================================
    // Guidance Flows
    // ========================================================================

    private fun showWelcome() {
        val welcomeContext = GuidanceContext(
            id = "echoela_welcome",
            topic = GuidanceTopic.WELCOME,
            title = "Hello, I'm Echoela",
            description = "I'm here to help you explore Echoelmusic at your own pace. I'll offer gentle guidance when you might need it, but you're always in control.",
            hints = emptyList(),
            steps = listOf(
                GuidanceStep("I'm Optional", "You can turn me off in Settings anytime. No pressure."),
                GuidanceStep("I Learn Your Style", "I'll adapt to how you use the app."),
                GuidanceStep("I Never Rush You", "Take all the time you need.")
            )
        )

        _currentContext.value = welcomeContext
        updatePreferences { it.copy(hasSeenWelcome = true) }
    }

    private fun showGuidance(context: GuidanceContext) {
        _currentContext.value = context
    }

    private fun showGeneralHelp() {
        val helpContext = GuidanceContext(
            id = "general_help",
            topic = GuidanceTopic.GENERAL_HELP,
            title = "How Can I Help?",
            description = "Choose what you'd like to learn about.",
            hints = emptyList(),
            steps = emptyList()
        )
        _currentContext.value = helpContext
    }

    // ========================================================================
    // Topic Completion
    // ========================================================================

    fun completeTopic(topic: GuidanceTopic) {
        _completedTopics.value = _completedTopics.value + topic
        saveProgress()
    }

    fun isTopicComplete(topic: GuidanceTopic): Boolean {
        return _completedTopics.value.contains(topic)
    }

    // ========================================================================
    // Accessibility
    // ========================================================================

    fun speak(message: String) {
        if (_preferences.value.voiceGuidance) {
            tts?.speak(message, TextToSpeech.QUEUE_FLUSH, null, null)
        }
    }

    fun announceForAccessibility(message: String) {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
        if (am?.isEnabled == true) {
            // Send accessibility event
        }
    }

    fun triggerHaptic() {
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        vibrator?.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    // ========================================================================
    // Preferences
    // ========================================================================

    private fun loadPreferences(): EchoelaPreferences {
        return EchoelaPreferences(
            isEnabled = prefs.getBoolean(KEY_IS_ENABLED, true),
            showHints = prefs.getBoolean(KEY_SHOW_HINTS, true),
            hasSeenWelcome = prefs.getBoolean(KEY_HAS_SEEN_WELCOME, false),
            textSize = TextSize.valueOf(prefs.getString(KEY_TEXT_SIZE, TextSize.MEDIUM.name) ?: TextSize.MEDIUM.name),
            useCalmColors = prefs.getBoolean(KEY_USE_CALM_COLORS, false),
            reduceAnimations = prefs.getBoolean(KEY_REDUCE_ANIMATIONS, false),
            voiceGuidance = prefs.getBoolean(KEY_VOICE_GUIDANCE, false)
        )
    }

    fun updatePreferences(update: (EchoelaPreferences) -> EchoelaPreferences) {
        val newPrefs = update(_preferences.value)
        _preferences.value = newPrefs

        prefs.edit().apply {
            putBoolean(KEY_IS_ENABLED, newPrefs.isEnabled)
            putBoolean(KEY_SHOW_HINTS, newPrefs.showHints)
            putBoolean(KEY_HAS_SEEN_WELCOME, newPrefs.hasSeenWelcome)
            putString(KEY_TEXT_SIZE, newPrefs.textSize.name)
            putBoolean(KEY_USE_CALM_COLORS, newPrefs.useCalmColors)
            putBoolean(KEY_REDUCE_ANIMATIONS, newPrefs.reduceAnimations)
            putBoolean(KEY_VOICE_GUIDANCE, newPrefs.voiceGuidance)
            apply()
        }
    }

    // ========================================================================
    // Persistence
    // ========================================================================

    private fun saveProgress() {
        prefs.edit().apply {
            putFloat(KEY_SKILL_LEVEL, _skillLevel.value)
            putFloat(KEY_CONFIDENCE, _confidenceScore.value)
            putFloat(KEY_GUIDANCE_DENSITY, _guidanceDensity.value)
            putStringSet(KEY_COMPLETED_TOPICS, _completedTopics.value.map { it.name }.toSet())
            apply()
        }
    }

    private fun loadProgress() {
        _skillLevel.value = prefs.getFloat(KEY_SKILL_LEVEL, 0.5f)
        _confidenceScore.value = prefs.getFloat(KEY_CONFIDENCE, 0.5f)
        _guidanceDensity.value = prefs.getFloat(KEY_GUIDANCE_DENSITY, 0.5f)

        val topicNames = prefs.getStringSet(KEY_COMPLETED_TOPICS, emptySet()) ?: emptySet()
        _completedTopics.value = topicNames.mapNotNull {
            try { GuidanceTopic.valueOf(it) } catch (e: Exception) { null }
        }.toSet()
    }

    fun resetProgress() {
        _skillLevel.value = 0.5f
        _confidenceScore.value = 0.5f
        _guidanceDensity.value = 0.5f
        _completedTopics.value = emptySet()

        prefs.edit().apply {
            remove(KEY_SKILL_LEVEL)
            remove(KEY_CONFIDENCE)
            remove(KEY_GUIDANCE_DENSITY)
            remove(KEY_COMPLETED_TOPICS)
            apply()
        }
    }

    fun cleanup() {
        scope.cancel()
        tts?.shutdown()
    }
}

// ============================================================================
// Data Classes
// ============================================================================

data class GuidanceContext(
    val id: String,
    val topic: GuidanceTopic,
    val title: String,
    val description: String,
    val hints: List<GuidanceHint>,
    val steps: List<GuidanceStep>
)

enum class GuidanceTopic {
    WELCOME,
    GENERAL_HELP,
    AUDIO_BASICS,
    BIOFEEDBACK,
    VISUALIZER,
    PRESETS,
    RECORDING,
    STREAMING,
    ACCESSIBILITY,
    SETTINGS,
    COLLABORATION,
    WELLNESS
}

data class GuidanceHint(
    val id: String = UUID.randomUUID().toString(),
    val shortText: String,
    val detailedText: String,
    val isExpanded: Boolean = false,
    val relatedTopics: List<GuidanceTopic> = emptyList()
)

data class GuidanceStep(
    val title: String,
    val description: String,
    val actionLabel: String? = null
)

data class HelpOffer(
    val id: String = UUID.randomUUID().toString(),
    val reason: HelpOfferReason,
    val context: GuidanceContext?,
    val message: String,
    val dismissable: Boolean,
    val timestamp: Long
)

enum class HelpOfferReason {
    HESITATION,
    REPEATED_ERRORS,
    FIRST_TIME,
    USER_REQUESTED
}

enum class UserError {
    NAVIGATION_ERROR,
    INPUT_ERROR,
    PERMISSION_ERROR,
    CONFIGURATION_ERROR,
    UNKNOWN
}

data class InteractionEvent(
    val type: InteractionType,
    val context: GuidanceContext?,
    val wasSuccessful: Boolean,
    val errorType: UserError? = null,
    val timestamp: Long = System.currentTimeMillis()
)

enum class InteractionType {
    TAP,
    GESTURE,
    VOICE,
    NAVIGATION,
    ERROR,
    COMPLETION
}

data class EchoelaPreferences(
    val isEnabled: Boolean = true,
    val showHints: Boolean = true,
    val hasSeenWelcome: Boolean = false,
    val textSize: TextSize = TextSize.MEDIUM,
    val useCalmColors: Boolean = false,
    val reduceAnimations: Boolean = false,
    val voiceGuidance: Boolean = false
)

enum class TextSize {
    SMALL,
    MEDIUM,
    LARGE,
    EXTRA_LARGE
}
