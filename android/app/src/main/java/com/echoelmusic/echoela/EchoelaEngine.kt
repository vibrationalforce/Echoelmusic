/**
 * EchoelaEngine.kt
 * Echoelmusic - Inclusive Intelligent Guide System (Android)
 *
 * Echoela is a calm, non-judgmental guide that:
 * - Adapts to user skill level and confidence
 * - Detects confusion and offers help without pressure
 * - Supports all accessibility profiles
 * - Is always optional and dismissible
 * - Has an adjustable personality (warm, playful, professional)
 * - Playfully peeks from behind UI elements
 * - Auto-hides during Live Performance mode
 * - Learns user thinking patterns and adapts
 * - Collects feedback for future updates
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
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
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
        private const val KEY_PERSONALITY = "personality"
        private const val KEY_USER_PROFILE = "user_profile"
        private const val KEY_SESSION_COUNT = "session_count"
        private const val KEY_PENDING_FEEDBACK = "pending_feedback"
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

    // Personality & Visual State (NEW)
    private val _personality = MutableStateFlow(loadPersonality())
    val personality: StateFlow<EchoelaPersonality> = _personality.asStateFlow()

    private val _peekState = MutableStateFlow(EchoelaPeekState())
    val peekState: StateFlow<EchoelaPeekState> = _peekState.asStateFlow()

    private val _isLivePerformanceMode = MutableStateFlow(false)
    val isLivePerformanceMode: StateFlow<Boolean> = _isLivePerformanceMode.asStateFlow()

    private val _userProfile = MutableStateFlow(loadUserProfile())
    val userProfile: StateFlow<UserLearningProfile> = _userProfile.asStateFlow()

    private val _pendingFeedback = MutableStateFlow<List<EchoelaFeedback>>(loadPendingFeedback())
    val pendingFeedback: StateFlow<List<EchoelaFeedback>> = _pendingFeedback.asStateFlow()

    private val _sessionCount = MutableStateFlow(prefs.getInt(KEY_SESSION_COUNT, 0))
    val sessionCount: StateFlow<Int> = _sessionCount.asStateFlow()

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    // Internal state
    private val interactionHistory = mutableListOf<InteractionEvent>()
    private var lastInteractionTime = System.currentTimeMillis()
    private var hesitationJob: Job? = null
    private var sessionStartTime = System.currentTimeMillis()
    private var peekAnimationJob: Job? = null

    // Text-to-speech
    private var tts: TextToSpeech? = null

    // JSON serializer
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

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

    // ========================================================================
    // Personality System
    // ========================================================================

    fun setPersonality(newPersonality: EchoelaPersonality) {
        _personality.value = newPersonality
        savePersonality()
    }

    fun applyPersonalityPreset(preset: PersonalityPreset) {
        _personality.value = when (preset) {
            PersonalityPreset.WARM -> EchoelaPersonality.warm()
            PersonalityPreset.PLAYFUL -> EchoelaPersonality.playful()
            PersonalityPreset.PROFESSIONAL -> EchoelaPersonality.professional()
            PersonalityPreset.MINIMAL -> EchoelaPersonality.minimal()
            PersonalityPreset.EMPATHETIC -> EchoelaPersonality.empathetic()
        }
        savePersonality()
    }

    private fun savePersonality() {
        prefs.edit().putString(KEY_PERSONALITY, json.encodeToString(_personality.value)).apply()
    }

    private fun loadPersonality(): EchoelaPersonality {
        val stored = prefs.getString(KEY_PERSONALITY, null) ?: return EchoelaPersonality()
        return try {
            json.decodeFromString<EchoelaPersonality>(stored)
        } catch (e: Exception) {
            EchoelaPersonality()
        }
    }

    fun personalizedMessage(baseMessage: String): String {
        var message = baseMessage
        val p = _personality.value

        // Add warmth
        if (p.warmth > 0.7f) {
            val warmPrefixes = listOf("Hey there! ", "Hi! ", "Hello! ", "")
            message = warmPrefixes.random() + message
        }

        // Add playfulness
        if (p.playfulness > 0.7f) {
            val playfulSuffixes = listOf(" 😊", " ✨", " 💡", "")
            message += playfulSuffixes.random()
        }

        // Adjust verbosity
        if (p.verbosity < 0.3f && message.length > 50) {
            message = message.take(50) + "..."
        }

        return message
    }

    // ========================================================================
    // Peek Animation System
    // ========================================================================

    fun peekFromEdge(edge: PeekEdge, message: String? = null) {
        if (_isLivePerformanceMode.value) return  // Never interrupt live performance

        _peekState.value = _peekState.value.copy(
            peekEdge = edge,
            animationPhase = PeekAnimationPhase.PEEKING,
            visibility = 0.3f
        )

        // After a playful peek, decide whether to fully appear
        peekAnimationJob?.cancel()
        peekAnimationJob = scope.launch {
            delay(1500)
            if (_peekState.value.animationPhase == PeekAnimationPhase.PEEKING) {
                if (shouldFullyAppear()) {
                    fullyAppear(message)
                } else {
                    retreatQuietly()
                }
            }
        }
    }

    private fun shouldFullyAppear(): Boolean {
        return _userSeemsConfused.value ||
               (System.currentTimeMillis() - lastInteractionTime > 3000)
    }

    private fun fullyAppear(message: String?) {
        _peekState.value = _peekState.value.copy(
            animationPhase = PeekAnimationPhase.VISIBLE,
            visibility = 1.0f
        )

        if (message != null) {
            if (_personality.value.playfulness > 0.5f) {
                offerHelp(HelpOfferReason.USER_REQUESTED)
            } else {
                offerHelp(HelpOfferReason.HESITATION)
            }
        }
    }

    fun retreatQuietly() {
        _peekState.value = _peekState.value.copy(
            animationPhase = PeekAnimationPhase.RETREATING,
            visibility = 0f
        )

        scope.launch {
            delay(500)
            _peekState.value = _peekState.value.copy(animationPhase = PeekAnimationPhase.HIDDEN)
        }
    }

    // ========================================================================
    // Live Performance Mode
    // ========================================================================

    fun enterLivePerformanceMode() {
        _isLivePerformanceMode.value = true
        retreatQuietly()
        _currentHint.value = null
        _pendingHelpOffer.value = null
    }

    fun exitLivePerformanceMode() {
        _isLivePerformanceMode.value = false

        if (_preferences.value.isEnabled && _isActive.value) {
            scope.launch {
                delay(2000)
                peekFromEdge(PeekEdge.BOTTOM_TRAILING, null)
            }
        }
    }

    fun checkLivePerformanceContext(contextName: String) {
        val liveContexts = listOf("streaming", "recording", "performance", "concert", "live", "broadcast")
        val shouldHide = liveContexts.any { contextName.lowercase().contains(it) }

        if (shouldHide && !_isLivePerformanceMode.value) {
            enterLivePerformanceMode()
        } else if (!shouldHide && _isLivePerformanceMode.value) {
            exitLivePerformanceMode()
        }
    }

    // ========================================================================
    // User Learning System
    // ========================================================================

    fun learnFromInteraction(event: InteractionEvent) {
        val profile = _userProfile.value.copy()

        // Track interaction patterns
        val patternKey = event.type.name
        val currentValue = profile.interactionPatterns[patternKey] ?: 0f
        profile.interactionPatterns[patternKey] = minOf(1f, currentValue + 0.1f)

        // Detect learning style
        when (event.type) {
            InteractionType.GESTURE -> profile.learningStyle = LearningStyle.KINESTHETIC
            InteractionType.VOICE -> profile.learningStyle = LearningStyle.AUDITORY
            InteractionType.TAP, InteractionType.NAVIGATION -> {
                if ((profile.interactionPatterns["NAVIGATION"] ?: 0f) > 0.5f) {
                    profile.learningStyle = LearningStyle.VISUAL
                }
            }
            else -> {}
        }

        // Track feature usage
        event.context?.id?.let { contextId ->
            if (event.wasSuccessful && !profile.favoriteFeatures.contains(contextId)) {
                profile.favoriteFeatures = (profile.favoriteFeatures + contextId).takeLast(10)
            }
        }

        // Track struggle areas
        event.context?.id?.let { contextId ->
            if (event.errorType != null && !profile.challengeAreas.contains(contextId)) {
                profile.challengeAreas = (profile.challengeAreas + contextId).takeLast(5)
            }
        }

        // Detect pace
        val avgInteractionTime = System.currentTimeMillis() - lastInteractionTime
        profile.pacePreference = when {
            avgInteractionTime < 1000 -> Pace.FAST
            avgInteractionTime > 5000 -> Pace.SLOW
            else -> Pace.MODERATE
        }

        profile.lastUpdated = System.currentTimeMillis()
        _userProfile.value = profile
        saveUserProfile()
    }

    fun trackHelpAcceptance(accepted: Boolean) {
        val weight = 0.1f
        val profile = _userProfile.value.copy()
        profile.helpAcceptanceRate = profile.helpAcceptanceRate * (1 - weight) + (if (accepted) 1f else 0f) * weight
        _userProfile.value = profile
        saveUserProfile()
    }

    private fun saveUserProfile() {
        prefs.edit().putString(KEY_USER_PROFILE, json.encodeToString(_userProfile.value)).apply()
    }

    private fun loadUserProfile(): UserLearningProfile {
        val stored = prefs.getString(KEY_USER_PROFILE, null) ?: return UserLearningProfile()
        return try {
            json.decodeFromString<UserLearningProfile>(stored)
        } catch (e: Exception) {
            UserLearningProfile()
        }
    }

    fun adaptToUser() {
        val profile = _userProfile.value

        // Adjust guidance density based on help acceptance
        if (profile.helpAcceptanceRate < 0.3f) {
            _guidanceDensity.value = maxOf(0.1f, _guidanceDensity.value - 0.1f)
        } else if (profile.helpAcceptanceRate > 0.7f) {
            _guidanceDensity.value = minOf(0.9f, _guidanceDensity.value + 0.1f)
        }

        // Adjust personality based on interaction patterns
        val p = _personality.value.copy()
        if ((profile.interactionPatterns["GESTURE"] ?: 0f) > 0.5f) {
            p.playfulness = minOf(1f, p.playfulness + 0.1f)
        }
        if (profile.pacePreference == Pace.FAST) {
            p.verbosity = maxOf(0.2f, p.verbosity - 0.1f)
        }
        _personality.value = p

        savePersonality()
        saveProgress()
    }

    // ========================================================================
    // Voice Guidance (Atmospheric)
    // ========================================================================

    fun speakWithPersonality(text: String) {
        if (!_preferences.value.voiceGuidance) return
        if (_isLivePerformanceMode.value) return

        val message = personalizedMessage(text)
        _isSpeaking.value = true

        tts?.setPitch(_personality.value.voicePitch)
        tts?.setSpeechRate(_personality.value.voiceSpeed)
        tts?.speak(message, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())

        scope.launch {
            delay((text.length * 60).toLong())
            _isSpeaking.value = false
        }
    }

    fun stopSpeaking() {
        tts?.stop()
        _isSpeaking.value = false
    }

    // ========================================================================
    // Feedback System
    // ========================================================================

    fun submitFeedback(
        type: FeedbackType,
        contextId: String,
        message: String,
        rating: Int? = null,
        suggestion: String? = null
    ) {
        val feedback = EchoelaFeedback(
            id = UUID.randomUUID().toString(),
            timestamp = System.currentTimeMillis(),
            feedbackType = type,
            context = contextId,
            message = message,
            rating = rating,
            suggestion = suggestion,
            systemInfo = FeedbackSystemInfo(
                skillLevel = _skillLevel.value,
                guidanceDensity = _guidanceDensity.value,
                personality = if (_personality.value.playfulness > 0.5f) "playful" else "warm",
                sessionCount = _sessionCount.value
            )
        )

        _pendingFeedback.value = _pendingFeedback.value + feedback
        savePendingFeedback()
        exportFeedbackToFile(feedback)

        if (_personality.value.warmth > 0.5f) {
            speakWithPersonality("Thank you for your feedback. It helps me improve.")
        }
    }

    private fun savePendingFeedback() {
        prefs.edit().putString(KEY_PENDING_FEEDBACK, json.encodeToString(_pendingFeedback.value)).apply()
    }

    private fun loadPendingFeedback(): List<EchoelaFeedback> {
        val stored = prefs.getString(KEY_PENDING_FEEDBACK, null) ?: return emptyList()
        return try {
            json.decodeFromString<List<EchoelaFeedback>>(stored)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun exportFeedbackToFile(feedback: EchoelaFeedback) {
        try {
            val feedbackDir = File(context.filesDir, "echoela_feedback")
            feedbackDir.mkdirs()
            val file = File(feedbackDir, "feedback_${feedback.id}.json")
            file.writeText(json.encodeToString(feedback))
        } catch (e: Exception) {
            // Silently fail - feedback export is not critical
        }
    }

    fun exportAllFeedback(): String? {
        return try {
            json.encodeToString(_pendingFeedback.value)
        } catch (e: Exception) {
            null
        }
    }

    fun clearSyncedFeedback() {
        _pendingFeedback.value = emptyList()
        savePendingFeedback()
    }

    // ========================================================================
    // Session Tracking
    // ========================================================================

    fun startSession() {
        sessionStartTime = System.currentTimeMillis()
        _sessionCount.value = _sessionCount.value + 1
        prefs.edit().putInt(KEY_SESSION_COUNT, _sessionCount.value).apply()

        // Track active hour
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val profile = _userProfile.value.copy()
        if (!profile.activeHours.contains(hour)) {
            profile.activeHours = (profile.activeHours + hour).takeLast(5)
            _userProfile.value = profile
            saveUserProfile()
        }
    }

    fun endSession() {
        val duration = System.currentTimeMillis() - sessionStartTime

        val profile = _userProfile.value.copy()
        val weight = 0.2
        profile.avgSessionDuration = (profile.avgSessionDuration * (1 - weight) + duration * weight).toLong()
        _userProfile.value = profile
        saveUserProfile()

        adaptToUser()
        saveProgress()
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

// ============================================================================
// Personality Data Classes
// ============================================================================

@Serializable
data class EchoelaPersonality(
    var warmth: Float = 0.7f,
    var playfulness: Float = 0.5f,
    var formality: Float = 0.3f,
    var verbosity: Float = 0.5f,
    var encouragement: Float = 0.6f,
    var voicePitch: Float = 1.0f,
    var voiceSpeed: Float = 0.9f
) {
    companion object {
        fun warm() = EchoelaPersonality(warmth = 0.9f, playfulness = 0.3f, formality = 0.2f, verbosity = 0.5f, encouragement = 0.8f, voicePitch = 1.0f, voiceSpeed = 0.85f)
        fun playful() = EchoelaPersonality(warmth = 0.7f, playfulness = 0.9f, formality = 0.1f, verbosity = 0.6f, encouragement = 0.7f, voicePitch = 1.1f, voiceSpeed = 1.0f)
        fun professional() = EchoelaPersonality(warmth = 0.5f, playfulness = 0.2f, formality = 0.8f, verbosity = 0.7f, encouragement = 0.4f, voicePitch = 0.95f, voiceSpeed = 0.95f)
        fun minimal() = EchoelaPersonality(warmth = 0.4f, playfulness = 0.1f, formality = 0.5f, verbosity = 0.2f, encouragement = 0.2f, voicePitch = 1.0f, voiceSpeed = 1.0f)
        fun empathetic() = EchoelaPersonality(warmth = 1.0f, playfulness = 0.4f, formality = 0.2f, verbosity = 0.6f, encouragement = 0.9f, voicePitch = 0.95f, voiceSpeed = 0.8f)
    }
}

enum class PersonalityPreset {
    WARM,
    PLAYFUL,
    PROFESSIONAL,
    MINIMAL,
    EMPATHETIC
}

// ============================================================================
// Peek Animation Data Classes
// ============================================================================

data class EchoelaPeekState(
    val peekEdge: PeekEdge = PeekEdge.BOTTOM_TRAILING,
    val visibility: Float = 0f,
    val animationPhase: PeekAnimationPhase = PeekAnimationPhase.HIDDEN,
    val backgroundTintAlpha: Float = 0.1f
)

enum class PeekEdge {
    BOTTOM_LEADING,
    BOTTOM_TRAILING,
    TOP_LEADING,
    TOP_TRAILING,
    BOTTOM,
    TRAILING,
    LEADING
}

enum class PeekAnimationPhase {
    HIDDEN,
    PEEKING,
    APPEARING,
    VISIBLE,
    EXPLAINING,
    RETREATING
}

// ============================================================================
// User Learning Data Classes
// ============================================================================

@Serializable
data class UserLearningProfile(
    var learningStyle: LearningStyle = LearningStyle.VISUAL,
    var pacePreference: Pace = Pace.MODERATE,
    var activeHours: List<Int> = emptyList(),
    var favoriteFeatures: List<String> = emptyList(),
    var challengeAreas: List<String> = emptyList(),
    var avgSessionDuration: Long = 300000L,
    var helpAcceptanceRate: Float = 0.5f,
    var interactionPatterns: MutableMap<String, Float> = mutableMapOf(),
    var lastUpdated: Long = System.currentTimeMillis()
)

enum class LearningStyle {
    VISUAL,
    AUDITORY,
    KINESTHETIC,
    READING
}

enum class Pace {
    SLOW,
    MODERATE,
    FAST
}

// ============================================================================
// Feedback Data Classes
// ============================================================================

@Serializable
data class EchoelaFeedback(
    val id: String,
    val timestamp: Long,
    val feedbackType: FeedbackType,
    val context: String,
    val message: String,
    val rating: Int? = null,
    val suggestion: String? = null,
    val systemInfo: FeedbackSystemInfo
)

@Serializable
data class FeedbackSystemInfo(
    val skillLevel: Float,
    val guidanceDensity: Float,
    val personality: String,
    val sessionCount: Int
)

enum class FeedbackType {
    SUGGESTION,
    ISSUE,
    PRAISE,
    CONFUSION,
    FEATURE_REQUEST,
    ACCESSIBILITY
}
