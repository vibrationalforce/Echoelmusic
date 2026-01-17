/**
 * EchoelaTest.kt
 * Comprehensive unit tests for Echoela Guide System and Security
 *
 * Created: 2026-01-15
 */

package com.echoelmusic

import com.echoelmusic.echoela.*
import org.junit.Assert.*
import org.junit.Test
import java.util.*

// ============================================================================
// GUIDANCE TOPIC TESTS
// ============================================================================

class GuidanceTopicTest {

    @Test
    fun `all guidance topics exist`() {
        assertEquals(12, GuidanceTopic.values().size)
        assertNotNull(GuidanceTopic.WELCOME)
        assertNotNull(GuidanceTopic.GENERAL_HELP)
        assertNotNull(GuidanceTopic.AUDIO_BASICS)
        assertNotNull(GuidanceTopic.BIOFEEDBACK)
        assertNotNull(GuidanceTopic.VISUALIZER)
        assertNotNull(GuidanceTopic.PRESETS)
        assertNotNull(GuidanceTopic.RECORDING)
        assertNotNull(GuidanceTopic.STREAMING)
        assertNotNull(GuidanceTopic.ACCESSIBILITY)
        assertNotNull(GuidanceTopic.SETTINGS)
        assertNotNull(GuidanceTopic.COLLABORATION)
        assertNotNull(GuidanceTopic.WELLNESS)
    }
}

// ============================================================================
// GUIDANCE CONTEXT TESTS
// ============================================================================

class GuidanceContextTest {

    @Test
    fun `guidance context creation`() {
        val context = GuidanceContext(
            id = "test_context",
            topic = GuidanceTopic.AUDIO_BASICS,
            title = "Audio Basics",
            description = "Learn the fundamentals",
            hints = emptyList(),
            steps = emptyList()
        )

        assertEquals("test_context", context.id)
        assertEquals(GuidanceTopic.AUDIO_BASICS, context.topic)
        assertEquals("Audio Basics", context.title)
    }

    @Test
    fun `guidance context with hints`() {
        val hint = GuidanceHint(
            shortText = "Quick tip",
            detailedText = "More detailed explanation here"
        )

        val context = GuidanceContext(
            id = "with_hints",
            topic = GuidanceTopic.VISUALIZER,
            title = "Visualizer",
            description = "Visual feedback",
            hints = listOf(hint),
            steps = emptyList()
        )

        assertEquals(1, context.hints.size)
        assertEquals("Quick tip", context.hints[0].shortText)
    }

    @Test
    fun `guidance context with steps`() {
        val step1 = GuidanceStep("Step 1", "First step description")
        val step2 = GuidanceStep("Step 2", "Second step description", "Continue")

        val context = GuidanceContext(
            id = "with_steps",
            topic = GuidanceTopic.RECORDING,
            title = "Recording",
            description = "How to record",
            hints = emptyList(),
            steps = listOf(step1, step2)
        )

        assertEquals(2, context.steps.size)
        assertEquals("Step 1", context.steps[0].title)
        assertEquals("Continue", context.steps[1].actionLabel)
    }
}

// ============================================================================
// GUIDANCE HINT TESTS
// ============================================================================

class GuidanceHintTest {

    @Test
    fun `hint has unique id`() {
        val hint1 = GuidanceHint(shortText = "Tip 1", detailedText = "Detail 1")
        val hint2 = GuidanceHint(shortText = "Tip 2", detailedText = "Detail 2")
        assertNotEquals(hint1.id, hint2.id)
    }

    @Test
    fun `hint default not expanded`() {
        val hint = GuidanceHint(shortText = "Tip", detailedText = "Detail")
        assertFalse(hint.isExpanded)
    }

    @Test
    fun `hint copy with expanded state`() {
        val hint = GuidanceHint(shortText = "Tip", detailedText = "Detail")
        val expanded = hint.copy(isExpanded = true)
        assertTrue(expanded.isExpanded)
        assertEquals(hint.id, expanded.id)
    }

    @Test
    fun `hint with related topics`() {
        val hint = GuidanceHint(
            shortText = "Recording hint",
            detailedText = "Full detail",
            relatedTopics = listOf(GuidanceTopic.STREAMING, GuidanceTopic.PRESETS)
        )
        assertEquals(2, hint.relatedTopics.size)
        assertTrue(hint.relatedTopics.contains(GuidanceTopic.STREAMING))
    }
}

// ============================================================================
// GUIDANCE STEP TESTS
// ============================================================================

class GuidanceStepTest {

    @Test
    fun `step creation with required fields`() {
        val step = GuidanceStep(
            title = "Configure Audio",
            description = "Set up your audio interface"
        )
        assertEquals("Configure Audio", step.title)
        assertEquals("Set up your audio interface", step.description)
        assertNull(step.actionLabel)
    }

    @Test
    fun `step with action label`() {
        val step = GuidanceStep(
            title = "Ready",
            description = "You're all set",
            actionLabel = "Start Now"
        )
        assertEquals("Start Now", step.actionLabel)
    }
}

// ============================================================================
// HELP OFFER TESTS
// ============================================================================

class HelpOfferTest {

    @Test
    fun `help offer has unique id`() {
        val offer1 = HelpOffer(
            reason = HelpOfferReason.HESITATION,
            context = null,
            message = "Need help?",
            dismissable = true,
            timestamp = System.currentTimeMillis()
        )
        val offer2 = HelpOffer(
            reason = HelpOfferReason.HESITATION,
            context = null,
            message = "Need help?",
            dismissable = true,
            timestamp = System.currentTimeMillis()
        )
        assertNotEquals(offer1.id, offer2.id)
    }

    @Test
    fun `help offer reasons exist`() {
        assertEquals(4, HelpOfferReason.values().size)
        assertNotNull(HelpOfferReason.HESITATION)
        assertNotNull(HelpOfferReason.REPEATED_ERRORS)
        assertNotNull(HelpOfferReason.FIRST_TIME)
        assertNotNull(HelpOfferReason.USER_REQUESTED)
    }
}

// ============================================================================
// USER ERROR TESTS
// ============================================================================

class UserErrorTest {

    @Test
    fun `all error types exist`() {
        assertEquals(5, UserError.values().size)
        assertNotNull(UserError.NAVIGATION_ERROR)
        assertNotNull(UserError.INPUT_ERROR)
        assertNotNull(UserError.PERMISSION_ERROR)
        assertNotNull(UserError.CONFIGURATION_ERROR)
        assertNotNull(UserError.UNKNOWN)
    }
}

// ============================================================================
// INTERACTION EVENT TESTS
// ============================================================================

class InteractionEventTest {

    @Test
    fun `interaction event creation`() {
        val event = InteractionEvent(
            type = InteractionType.TAP,
            context = null,
            wasSuccessful = true
        )
        assertEquals(InteractionType.TAP, event.type)
        assertTrue(event.wasSuccessful)
        assertNull(event.errorType)
    }

    @Test
    fun `interaction event with error`() {
        val event = InteractionEvent(
            type = InteractionType.ERROR,
            context = null,
            wasSuccessful = false,
            errorType = UserError.INPUT_ERROR
        )
        assertFalse(event.wasSuccessful)
        assertEquals(UserError.INPUT_ERROR, event.errorType)
    }

    @Test
    fun `interaction event timestamp auto-set`() {
        val before = System.currentTimeMillis()
        val event = InteractionEvent(
            type = InteractionType.NAVIGATION,
            context = null,
            wasSuccessful = true
        )
        val after = System.currentTimeMillis()
        assertTrue(event.timestamp >= before)
        assertTrue(event.timestamp <= after)
    }

    @Test
    fun `all interaction types exist`() {
        assertEquals(6, InteractionType.values().size)
        assertNotNull(InteractionType.TAP)
        assertNotNull(InteractionType.GESTURE)
        assertNotNull(InteractionType.VOICE)
        assertNotNull(InteractionType.NAVIGATION)
        assertNotNull(InteractionType.ERROR)
        assertNotNull(InteractionType.COMPLETION)
    }
}

// ============================================================================
// ECHOELA PREFERENCES TESTS
// ============================================================================

class EchoelaPreferencesTest {

    @Test
    fun `default preferences`() {
        val prefs = EchoelaPreferences()
        assertTrue(prefs.isEnabled)
        assertTrue(prefs.showHints)
        assertFalse(prefs.hasSeenWelcome)
        assertEquals(TextSize.MEDIUM, prefs.textSize)
        assertFalse(prefs.useCalmColors)
        assertFalse(prefs.reduceAnimations)
        assertFalse(prefs.voiceGuidance)
    }

    @Test
    fun `custom preferences`() {
        val prefs = EchoelaPreferences(
            isEnabled = false,
            showHints = false,
            hasSeenWelcome = true,
            textSize = TextSize.LARGE,
            useCalmColors = true,
            reduceAnimations = true,
            voiceGuidance = true
        )
        assertFalse(prefs.isEnabled)
        assertTrue(prefs.useCalmColors)
        assertEquals(TextSize.LARGE, prefs.textSize)
    }

    @Test
    fun `all text sizes exist`() {
        assertEquals(4, TextSize.values().size)
        assertNotNull(TextSize.SMALL)
        assertNotNull(TextSize.MEDIUM)
        assertNotNull(TextSize.LARGE)
        assertNotNull(TextSize.EXTRA_LARGE)
    }
}

// ============================================================================
// ECHOELA PERSONALITY TESTS
// ============================================================================

class EchoelaPersonalityTest {

    @Test
    fun `default personality`() {
        val p = EchoelaPersonality()
        assertEquals(0.7f, p.warmth, 0.001f)
        assertEquals(0.5f, p.playfulness, 0.001f)
        assertEquals(0.3f, p.formality, 0.001f)
        assertEquals(0.5f, p.verbosity, 0.001f)
        assertEquals(0.6f, p.encouragement, 0.001f)
        assertEquals(1.0f, p.voicePitch, 0.001f)
        assertEquals(0.9f, p.voiceSpeed, 0.001f)
    }

    @Test
    fun `warm personality preset`() {
        val p = EchoelaPersonality.warm()
        assertEquals(0.9f, p.warmth, 0.001f)
        assertEquals(0.3f, p.playfulness, 0.001f)
        assertEquals(0.8f, p.encouragement, 0.001f)
    }

    @Test
    fun `playful personality preset`() {
        val p = EchoelaPersonality.playful()
        assertEquals(0.9f, p.playfulness, 0.001f)
        assertEquals(0.1f, p.formality, 0.001f)
        assertEquals(1.1f, p.voicePitch, 0.001f)
    }

    @Test
    fun `professional personality preset`() {
        val p = EchoelaPersonality.professional()
        assertEquals(0.8f, p.formality, 0.001f)
        assertEquals(0.2f, p.playfulness, 0.001f)
        assertEquals(0.7f, p.verbosity, 0.001f)
    }

    @Test
    fun `minimal personality preset`() {
        val p = EchoelaPersonality.minimal()
        assertEquals(0.2f, p.verbosity, 0.001f)
        assertEquals(0.1f, p.playfulness, 0.001f)
        assertEquals(0.2f, p.encouragement, 0.001f)
    }

    @Test
    fun `empathetic personality preset`() {
        val p = EchoelaPersonality.empathetic()
        assertEquals(1.0f, p.warmth, 0.001f)
        assertEquals(0.9f, p.encouragement, 0.001f)
        assertEquals(0.8f, p.voiceSpeed, 0.001f)
    }

    @Test
    fun `all personality presets exist`() {
        assertEquals(5, PersonalityPreset.values().size)
        assertNotNull(PersonalityPreset.WARM)
        assertNotNull(PersonalityPreset.PLAYFUL)
        assertNotNull(PersonalityPreset.PROFESSIONAL)
        assertNotNull(PersonalityPreset.MINIMAL)
        assertNotNull(PersonalityPreset.EMPATHETIC)
    }
}

// ============================================================================
// PEEK ANIMATION TESTS
// ============================================================================

class EchoelaPeekStateTest {

    @Test
    fun `default peek state is hidden`() {
        val state = EchoelaPeekState()
        assertEquals(PeekEdge.BOTTOM_TRAILING, state.peekEdge)
        assertEquals(0f, state.visibility, 0.001f)
        assertEquals(PeekAnimationPhase.HIDDEN, state.animationPhase)
    }

    @Test
    fun `peek state with custom values`() {
        val state = EchoelaPeekState(
            peekEdge = PeekEdge.TOP_LEADING,
            visibility = 0.7f,
            animationPhase = PeekAnimationPhase.PEEKING
        )
        assertEquals(PeekEdge.TOP_LEADING, state.peekEdge)
        assertEquals(0.7f, state.visibility, 0.001f)
    }

    @Test
    fun `all peek edges exist`() {
        assertEquals(7, PeekEdge.values().size)
        assertNotNull(PeekEdge.BOTTOM_LEADING)
        assertNotNull(PeekEdge.BOTTOM_TRAILING)
        assertNotNull(PeekEdge.TOP_LEADING)
        assertNotNull(PeekEdge.TOP_TRAILING)
        assertNotNull(PeekEdge.BOTTOM)
        assertNotNull(PeekEdge.TRAILING)
        assertNotNull(PeekEdge.LEADING)
    }

    @Test
    fun `all animation phases exist`() {
        assertEquals(6, PeekAnimationPhase.values().size)
        assertNotNull(PeekAnimationPhase.HIDDEN)
        assertNotNull(PeekAnimationPhase.PEEKING)
        assertNotNull(PeekAnimationPhase.APPEARING)
        assertNotNull(PeekAnimationPhase.VISIBLE)
        assertNotNull(PeekAnimationPhase.EXPLAINING)
        assertNotNull(PeekAnimationPhase.RETREATING)
    }
}

// ============================================================================
// USER LEARNING PROFILE TESTS
// ============================================================================

class UserLearningProfileTest {

    @Test
    fun `default learning profile`() {
        val profile = UserLearningProfile()
        assertEquals(LearningStyle.VISUAL, profile.learningStyle)
        assertEquals(Pace.MODERATE, profile.pacePreference)
        assertTrue(profile.activeHours.isEmpty())
        assertTrue(profile.favoriteFeatures.isEmpty())
        assertTrue(profile.challengeAreas.isEmpty())
        assertEquals(300000L, profile.avgSessionDuration)
        assertEquals(0.5f, profile.helpAcceptanceRate, 0.001f)
    }

    @Test
    fun `all learning styles exist`() {
        assertEquals(4, LearningStyle.values().size)
        assertNotNull(LearningStyle.VISUAL)
        assertNotNull(LearningStyle.AUDITORY)
        assertNotNull(LearningStyle.KINESTHETIC)
        assertNotNull(LearningStyle.READING)
    }

    @Test
    fun `all pace values exist`() {
        assertEquals(3, Pace.values().size)
        assertNotNull(Pace.SLOW)
        assertNotNull(Pace.MODERATE)
        assertNotNull(Pace.FAST)
    }

    @Test
    fun `profile with custom values`() {
        val profile = UserLearningProfile(
            learningStyle = LearningStyle.KINESTHETIC,
            pacePreference = Pace.FAST,
            activeHours = listOf(9, 10, 14, 15),
            favoriteFeatures = listOf("audio", "visualizer"),
            helpAcceptanceRate = 0.8f
        )
        assertEquals(LearningStyle.KINESTHETIC, profile.learningStyle)
        assertEquals(4, profile.activeHours.size)
        assertEquals(2, profile.favoriteFeatures.size)
    }
}

// ============================================================================
// FEEDBACK TESTS
// ============================================================================

class EchoelaFeedbackTest {

    @Test
    fun `feedback creation`() {
        val systemInfo = FeedbackSystemInfo(
            skillLevel = 0.6f,
            guidanceDensity = 0.5f,
            personality = "warm",
            sessionCount = 10
        )

        val feedback = EchoelaFeedback(
            id = UUID.randomUUID().toString(),
            timestamp = System.currentTimeMillis(),
            feedbackType = FeedbackType.SUGGESTION,
            context = "audio_settings",
            message = "Great feature!",
            rating = 5,
            systemInfo = systemInfo
        )

        assertEquals(FeedbackType.SUGGESTION, feedback.feedbackType)
        assertEquals("audio_settings", feedback.context)
        assertEquals(5, feedback.rating)
        assertEquals(0.6f, feedback.systemInfo.skillLevel, 0.001f)
    }

    @Test
    fun `all feedback types exist`() {
        assertEquals(6, FeedbackType.values().size)
        assertNotNull(FeedbackType.SUGGESTION)
        assertNotNull(FeedbackType.ISSUE)
        assertNotNull(FeedbackType.PRAISE)
        assertNotNull(FeedbackType.CONFUSION)
        assertNotNull(FeedbackType.FEATURE_REQUEST)
        assertNotNull(FeedbackType.ACCESSIBILITY)
    }

    @Test
    fun `feedback system info creation`() {
        val info = FeedbackSystemInfo(
            skillLevel = 0.3f,
            guidanceDensity = 0.7f,
            personality = "playful",
            sessionCount = 5
        )
        assertEquals(0.3f, info.skillLevel, 0.001f)
        assertEquals(5, info.sessionCount)
    }
}

// ============================================================================
// SECURITY LEVEL TESTS
// ============================================================================

class EchoelaSecurityLevelTest {

    @Test
    fun `all security levels exist`() {
        assertEquals(4, EchoelaSecurityLevel.values().size)
        assertNotNull(EchoelaSecurityLevel.STANDARD)
        assertNotNull(EchoelaSecurityLevel.ENHANCED)
        assertNotNull(EchoelaSecurityLevel.MAXIMUM)
        assertNotNull(EchoelaSecurityLevel.PARANOID)
    }
}

// ============================================================================
// PRIVACY CONFIG TESTS
// ============================================================================

class EchoelaPrivacyConfigTest {

    @Test
    fun `default privacy config`() {
        val config = EchoelaPrivacyConfig()
        assertFalse(config.hasConsented)
        assertEquals(0L, config.consentTimestamp)
        assertEquals("1.0", config.consentVersion)
        assertFalse(config.allowLearningProfile)
        assertFalse(config.allowFeedback)
        assertFalse(config.allowVoiceProcessing)
        assertFalse(config.allowAnalytics)
        assertEquals(30, config.dataRetentionDays)
        assertTrue(config.autoDeleteEnabled)
        assertTrue(config.anonymizeFeedback)
        assertEquals("auto", config.complianceRegion)
    }

    @Test
    fun `privacy config with consent`() {
        val config = EchoelaPrivacyConfig(
            hasConsented = true,
            consentTimestamp = System.currentTimeMillis(),
            allowLearningProfile = true,
            allowFeedback = true,
            allowVoiceProcessing = false,
            allowAnalytics = false,
            dataRetentionDays = 90,
            complianceRegion = "EU"
        )
        assertTrue(config.hasConsented)
        assertTrue(config.allowLearningProfile)
        assertFalse(config.allowVoiceProcessing)
        assertEquals(90, config.dataRetentionDays)
        assertEquals("EU", config.complianceRegion)
    }
}

// ============================================================================
// DATA EXPORT TESTS
// ============================================================================

class EchoelaDataExportTest {

    @Test
    fun `data export creation`() {
        val config = EchoelaPrivacyConfig(hasConsented = true)
        val profile = UserLearningProfile()

        val export = EchoelaDataExport(
            exportTimestamp = System.currentTimeMillis(),
            privacyConfig = config,
            learningProfile = profile,
            feedbackHistory = emptyList()
        )

        assertTrue(export.exportTimestamp > 0)
        assertTrue(export.privacyConfig.hasConsented)
        assertNotNull(export.learningProfile)
        assertTrue(export.feedbackHistory.isEmpty())
    }

    @Test
    fun `data export with null profile`() {
        val export = EchoelaDataExport(
            exportTimestamp = System.currentTimeMillis(),
            privacyConfig = EchoelaPrivacyConfig(),
            learningProfile = null,
            feedbackHistory = emptyList()
        )
        assertNull(export.learningProfile)
    }
}

// ============================================================================
// ANONYMIZED FEEDBACK TESTS
// ============================================================================

class AnonymizedFeedbackTest {

    @Test
    fun `anonymized feedback creation`() {
        val anonymized = AnonymizedFeedback(
            id = "abc12345",
            timestamp = 1704067200000L, // Rounded to day
            feedbackType = "SUGGESTION",
            context = "a1b2c3d4", // Hashed
            message = "Great app!",
            rating = 5,
            skillLevelRange = "intermediate",
            sessionCountRange = "regular"
        )

        assertEquals("abc12345", anonymized.id)
        assertEquals("SUGGESTION", anonymized.feedbackType)
        assertEquals("intermediate", anonymized.skillLevelRange)
        assertEquals("regular", anonymized.sessionCountRange)
    }

    @Test
    fun `anonymized feedback without rating`() {
        val anonymized = AnonymizedFeedback(
            id = "xyz98765",
            timestamp = System.currentTimeMillis(),
            feedbackType = "ISSUE",
            context = "hashed123",
            message = "Found a bug",
            rating = null,
            skillLevelRange = "beginner",
            sessionCountRange = "new"
        )
        assertNull(anonymized.rating)
    }
}
