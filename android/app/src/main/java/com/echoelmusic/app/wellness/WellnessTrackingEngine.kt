package com.echoelmusic.app.wellness

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.*
import kotlin.math.cos
import kotlin.math.sin

/**
 * Echoelmusic Wellness Tracking Engine for Android
 * Personal wellness tracking and mindfulness tools
 *
 * DISCLAIMER: This software is for general wellness and entertainment
 * purposes only. It does NOT provide medical advice, diagnosis, or treatment.
 * Always consult qualified healthcare professionals for medical concerns.
 *
 * Port of iOS WellnessTrackingEngine with Kotlin coroutines
 */

// MARK: - Wellness Disclaimer

object WellnessDisclaimer {
    const val FULL = """
IMPORTANT WELLNESS DISCLAIMER

This application is designed for general wellness, relaxation, and entertainment purposes only.

This app does NOT:
- Provide medical advice, diagnosis, or treatment
- Replace professional healthcare guidance
- Claim to cure, treat, or prevent any medical condition
- Make any health claims beyond general wellness support

The biofeedback features are for self-exploration and relaxation only.
The meditation and breathing exercises are general wellness practices.

If you have any health concerns, please consult a qualified healthcare professional.

By using this app, you acknowledge that you understand these limitations.
"""

    const val SHORT = "For general wellness only. Not medical advice. Consult healthcare professionals for medical concerns."

    const val MEDITATION = "Meditation is a general wellness practice. Results vary. Not a substitute for professional mental health support."

    const val BIOFEEDBACK = "Biofeedback readings are for self-awareness only. Not diagnostic. Consult professionals for health concerns."
}

// MARK: - Wellness Category

enum class WellnessCategory(val displayName: String, val description: String) {
    // Relaxation
    RELAXATION("Relaxation", "General relaxation practices"),
    STRESS_RELIEF("Stress Relief", "Techniques for everyday stress management"),
    CALMNESS("Calmness", "Practices for cultivating calm"),
    TRANQUILITY("Tranquility", "Deep tranquility practices"),

    // Mindfulness
    MEDITATION("Meditation", "Traditional meditation practices"),
    BREATHWORK("Breathwork", "Breathing exercises for wellness"),
    MINDFULNESS("Mindfulness", "Mindful awareness practices"),
    PRESENCE("Present Moment", "Being present practices"),
    GRATITUDE("Gratitude", "Gratitude and appreciation practices"),

    // Focus
    FOCUS("Focus", "Attention and focus practices"),
    CONCENTRATION("Concentration", "Concentration training"),
    CREATIVITY("Creativity", "Creative flow practices"),
    CLARITY("Mental Clarity", "Practices for mental clarity"),

    // Energy
    ENERGIZING("Energizing", "Energizing practices"),
    MOTIVATION("Motivation", "Motivation and drive practices"),
    VITALITY("Vitality", "Vitality enhancement"),
    AWAKENING("Awakening", "Morning awakening practices"),

    // Rest
    SLEEP_SUPPORT("Sleep Support", "Practices to support restful sleep"),
    WIND_DOWN("Wind Down", "Evening wind-down practices"),
    RESTFUL("Restful", "Rest and recovery practices"),
    RECOVERY("Recovery", "Recovery support practices"),

    // Movement
    GENTLE_MOVEMENT("Gentle Movement", "Gentle physical practices"),
    STRETCHING("Stretching", "Stretching and flexibility"),
    BODY_AWARENESS("Body Awareness", "Body awareness practices"),
    GROUNDING("Grounding", "Grounding and centering practices"),

    // Social
    CONNECTION("Connection", "Connection practices"),
    COMPASSION("Compassion", "Compassion cultivation"),
    SELF_CARE("Self-Care", "Self-care practices"),
    EMOTIONAL("Emotional Wellness", "Emotional wellness support")
}

// MARK: - Mood Level

enum class MoodLevel(val value: Int, val emoji: String) {
    VERY_LOW(1, "😔"),
    LOW(2, "😕"),
    NEUTRAL(3, "😐"),
    GOOD(4, "🙂"),
    GREAT(5, "😊")
}

// MARK: - Biofeedback Snapshot

data class BiofeedbackSnapshot(
    val coherenceLevel: Float? = null,
    val calmness: Float? = null,
    val breathingRate: Float? = null,
    val timestamp: Long = System.currentTimeMillis()
)

// MARK: - Wellness Session

data class WellnessSession(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var category: WellnessCategory,
    var duration: Long = 0, // milliseconds
    val startTime: Long = System.currentTimeMillis(),
    var endTime: Long? = null,
    var notes: String? = null,
    var moodBefore: MoodLevel? = null,
    var moodAfter: MoodLevel? = null,
    var biofeedback: BiofeedbackSnapshot? = null
) {
    val isComplete: Boolean get() = endTime != null

    val actualDuration: Long get() {
        return endTime?.let { it - startTime } ?: (System.currentTimeMillis() - startTime)
    }

    val durationMinutes: Int get() = (actualDuration / 60000).toInt()
}

// MARK: - Breathing Pattern

data class BreathingPattern(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val description: String,
    val inhaleSeconds: Double,
    val holdInSeconds: Double,
    val exhaleSeconds: Double,
    val holdOutSeconds: Double,
    val cycles: Int,
    val category: WellnessCategory = WellnessCategory.BREATHWORK
) {
    val cycleDuration: Double get() = inhaleSeconds + holdInSeconds + exhaleSeconds + holdOutSeconds
    val totalDuration: Double get() = cycleDuration * cycles

    companion object {
        val BOX_BREATHING = BreathingPattern(
            name = "Box Breathing",
            description = "Equal inhale, hold, exhale, hold. A balanced technique.",
            inhaleSeconds = 4.0, holdInSeconds = 4.0, exhaleSeconds = 4.0, holdOutSeconds = 4.0,
            cycles = 6, category = WellnessCategory.RELAXATION
        )

        val RELAXING_BREATH = BreathingPattern(
            name = "Relaxing Breath (4-7-8)",
            description = "Extended exhale for relaxation support.",
            inhaleSeconds = 4.0, holdInSeconds = 7.0, exhaleSeconds = 8.0, holdOutSeconds = 0.0,
            cycles = 4, category = WellnessCategory.SLEEP_SUPPORT
        )

        val ENERGIZING_BREATH = BreathingPattern(
            name = "Energizing Breath",
            description = "Quick breaths for an energizing sensation.",
            inhaleSeconds = 2.0, holdInSeconds = 0.0, exhaleSeconds = 2.0, holdOutSeconds = 0.0,
            cycles = 20, category = WellnessCategory.ENERGIZING
        )

        val CALMING_BREATH = BreathingPattern(
            name = "Calming Breath",
            description = "Slow, deep breaths for calmness.",
            inhaleSeconds = 5.0, holdInSeconds = 2.0, exhaleSeconds = 7.0, holdOutSeconds = 2.0,
            cycles = 5, category = WellnessCategory.CALMNESS
        )

        val COHERENCE_BREATH = BreathingPattern(
            name = "Coherence Breath",
            description = "5-second rhythm associated with relaxation states.",
            inhaleSeconds = 5.0, holdInSeconds = 0.0, exhaleSeconds = 5.0, holdOutSeconds = 0.0,
            cycles = 12, category = WellnessCategory.MINDFULNESS
        )

        val MORNING_BREATH = BreathingPattern(
            name = "Morning Awakening",
            description = "Gentle breath pattern for starting the day.",
            inhaleSeconds = 4.0, holdInSeconds = 2.0, exhaleSeconds = 4.0, holdOutSeconds = 1.0,
            cycles = 8, category = WellnessCategory.AWAKENING
        )

        val ALL_PATTERNS = listOf(
            BOX_BREATHING, RELAXING_BREATH, ENERGIZING_BREATH,
            CALMING_BREATH, COHERENCE_BREATH, MORNING_BREATH
        )
    }
}

// MARK: - Meditation Guide

enum class MeditationDifficulty(val displayName: String) {
    BEGINNER("Beginner"),
    INTERMEDIATE("Intermediate"),
    ADVANCED("Advanced")
}

data class MeditationInstruction(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val startTime: Long, // milliseconds
    val duration: Long,
    val voiceGuidance: Boolean = true
)

data class MeditationGuide(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val description: String,
    val duration: Long, // milliseconds
    val category: WellnessCategory,
    val difficulty: MeditationDifficulty = MeditationDifficulty.BEGINNER,
    val instructions: List<MeditationInstruction> = emptyList(),
    val audioUrl: String? = null
) {
    companion object {
        val BODY_SCANNING = MeditationGuide(
            title = "Body Awareness",
            description = "A gentle practice to bring awareness to different parts of your body.",
            duration = 600000, // 10 minutes
            category = WellnessCategory.BODY_AWARENESS,
            difficulty = MeditationDifficulty.BEGINNER
        )

        val BREATH_AWARENESS = MeditationGuide(
            title = "Breath Awareness",
            description = "Simply notice your natural breathing without trying to change it.",
            duration = 300000, // 5 minutes
            category = WellnessCategory.MINDFULNESS,
            difficulty = MeditationDifficulty.BEGINNER
        )

        val LOVING_KINDNESS = MeditationGuide(
            title = "Kindness Practice",
            description = "Cultivate feelings of goodwill towards yourself and others.",
            duration = 900000, // 15 minutes
            category = WellnessCategory.COMPASSION,
            difficulty = MeditationDifficulty.INTERMEDIATE
        )

        val GRATITUDE_REFLECTION = MeditationGuide(
            title = "Gratitude Reflection",
            description = "Reflect on things you appreciate in your life.",
            duration = 600000, // 10 minutes
            category = WellnessCategory.GRATITUDE,
            difficulty = MeditationDifficulty.BEGINNER
        )

        val FOCUS_TRAINING = MeditationGuide(
            title = "Focus Training",
            description = "Practice bringing attention to a single point of focus.",
            duration = 600000, // 10 minutes
            category = WellnessCategory.FOCUS,
            difficulty = MeditationDifficulty.INTERMEDIATE
        )

        val ALL_GUIDES = listOf(
            BODY_SCANNING, BREATH_AWARENESS, LOVING_KINDNESS,
            GRATITUDE_REFLECTION, FOCUS_TRAINING
        )
    }
}

// MARK: - Wellness Goal

data class DailyProgress(
    val id: String = UUID.randomUUID().toString(),
    val date: Long,
    var minutesCompleted: Int,
    var sessionsCompleted: Int
)

data class WellnessGoal(
    val id: String = UUID.randomUUID().toString(),
    var title: String,
    var description: String = "",
    var category: WellnessCategory,
    var targetMinutesPerDay: Int = 10,
    var targetDaysPerWeek: Int = 5,
    val startDate: Long = System.currentTimeMillis(),
    val progress: MutableList<DailyProgress> = mutableListOf(),
    var isActive: Boolean = true
) {
    val weeklyProgress: Double get() {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
        val startOfWeek = calendar.timeInMillis

        val thisWeekProgress = progress.filter { it.date >= startOfWeek }
        val daysWithTarget = thisWeekProgress.count { it.minutesCompleted >= targetMinutesPerDay }
        return daysWithTarget.toDouble() / targetDaysPerWeek
    }
}

// MARK: - Journal Entry

data class JournalEntry(
    val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    var title: String,
    var content: String,
    var mood: MoodLevel,
    var tags: List<String> = emptyList(),
    var category: WellnessCategory? = null,
    var isPrivate: Boolean = true
)

// MARK: - Wellness Statistics

data class WellnessStatistics(
    val totalSessions: Int = 0,
    val totalMinutes: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val favoriteCategory: WellnessCategory? = null,
    val averageMoodBefore: Double = 3.0,
    val averageMoodAfter: Double = 3.0,
    val moodImprovement: Double = 0.0,
    val weeklyMinutes: List<Int> = listOf(0, 0, 0, 0, 0, 0, 0)
) {
    companion object {
        val EMPTY = WellnessStatistics()
    }
}

// MARK: - Sound Bath Generator

enum class SoundType(val displayName: String) {
    TIBETAN_BOWLS("Tibetan Bowls"),
    CRYSTAL_BOWLS("Crystal Bowls"),
    OCEAN_WAVES("Ocean Waves"),
    RAINFOREST("Rainforest"),
    FIREPLACE("Fireplace"),
    WHITE_NOISE("White Noise"),
    PINK_NOISE("Pink Noise"),
    BROWN_NOISE("Brown Noise"),
    BINAURAL("Multidimensional Brainwave Entrainment"),
    ISOCHRONIC("Isochronic Tones"),
    BRAINWAVE("Brainwave Entrainment"),
    QUANTUM_HARMONICS("Quantum Harmonics")
}

class SoundBathGenerator {
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying

    private val _volume = MutableStateFlow(0.7f)
    val volume: StateFlow<Float> = _volume

    private val _selectedSounds = MutableStateFlow<Set<SoundType>>(setOf(SoundType.TIBETAN_BOWLS))
    val selectedSounds: StateFlow<Set<SoundType>> = _selectedSounds

    private val _binauralFrequency = MutableStateFlow(10.0f) // Alpha waves
    val binauralFrequency: StateFlow<Float> = _binauralFrequency

    fun play() {
        _isPlaying.value = true
    }

    fun pause() {
        _isPlaying.value = false
    }

    fun stop() {
        _isPlaying.value = false
    }

    fun setVolume(vol: Float) {
        _volume.value = vol.coerceIn(0f, 1f)
    }

    fun selectSound(sound: SoundType) {
        _selectedSounds.value = _selectedSounds.value + sound
    }

    fun deselectSound(sound: SoundType) {
        _selectedSounds.value = _selectedSounds.value - sound
    }

    fun setBinauralFrequency(freq: Float) {
        _binauralFrequency.value = freq.coerceIn(0.5f, 100f)
    }
}

// MARK: - Mindful Reminder

data class MindfulReminder(
    val id: String = UUID.randomUUID().toString(),
    var message: String,
    var category: WellnessCategory,
    var time: Long,
    var isEnabled: Boolean = true,
    var repeatDays: Set<Int> = setOf(1, 2, 3, 4, 5, 6, 7) // All days
) {
    companion object {
        val SUGGESTIONS = listOf(
            "Take a moment to breathe deeply",
            "Notice how your body feels right now",
            "What are you grateful for today?",
            "Take a mindful pause",
            "Check in with yourself",
            "Time for a wellness break"
        )
    }
}

// MARK: - Wellness Recommendation

data class WellnessRecommendation(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val description: String,
    val category: WellnessCategory,
    val duration: Long // milliseconds
)

// MARK: - Wellness Tracking Engine

class WellnessTrackingEngine {

    companion object {
        private const val TAG = "WellnessEngine"
    }

    // State
    private val _isSessionActive = MutableStateFlow(false)
    val isSessionActive: StateFlow<Boolean> = _isSessionActive

    private val _currentSession = MutableStateFlow<WellnessSession?>(null)
    val currentSession: StateFlow<WellnessSession?> = _currentSession

    private val _sessions = MutableStateFlow<List<WellnessSession>>(emptyList())
    val sessions: StateFlow<List<WellnessSession>> = _sessions

    private val _goals = MutableStateFlow<List<WellnessGoal>>(emptyList())
    val goals: StateFlow<List<WellnessGoal>> = _goals

    private val _journal = MutableStateFlow<List<JournalEntry>>(emptyList())
    val journal: StateFlow<List<JournalEntry>> = _journal

    private val _statistics = MutableStateFlow(WellnessStatistics.EMPTY)
    val statistics: StateFlow<WellnessStatistics> = _statistics

    private val _selectedCategory = MutableStateFlow(WellnessCategory.RELAXATION)
    val selectedCategory: StateFlow<WellnessCategory> = _selectedCategory

    // Biofeedback (non-medical)
    private val _currentCoherence = MutableStateFlow(0.5f)
    val currentCoherence: StateFlow<Float> = _currentCoherence

    private val _currentCalmness = MutableStateFlow(0.5f)
    val currentCalmness: StateFlow<Float> = _currentCalmness

    // Processing
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var biofeedbackJob: Job? = null
    private var breathingJob: Job? = null

    val soundBathGenerator = SoundBathGenerator()

    init {
        setupBiofeedbackSimulation()
        loadSavedData()
    }

    private fun setupBiofeedbackSimulation() {
        biofeedbackJob?.cancel()
        biofeedbackJob = scope.launch {
            while (isActive) {
                updateBiofeedback()
                delay(1000)
            }
        }
    }

    private fun updateBiofeedback() {
        // Simulated biofeedback for visualization (not medical)
        val time = System.currentTimeMillis() / 1000.0
        val baseCoherence = if (_isSessionActive.value) 0.6f else 0.4f
        _currentCoherence.value = (baseCoherence + 0.3f * sin(time * 0.2).toFloat()).coerceIn(0f, 1f)
        _currentCalmness.value = (baseCoherence + 0.25f * cos(time * 0.15).toFloat()).coerceIn(0f, 1f)
    }

    private fun loadSavedData() {
        // Load saved sessions, goals, journal from SharedPreferences or database
        updateStatistics()
    }

    // MARK: - Session Management

    fun startSession(name: String, category: WellnessCategory, moodBefore: MoodLevel? = null) {
        if (_isSessionActive.value) return

        val session = WellnessSession(
            name = name,
            category = category,
            moodBefore = moodBefore
        )

        _currentSession.value = session
        _isSessionActive.value = true

        Log.i(TAG, "Started '$name' session (${category.displayName})")
        Log.i(TAG, WellnessDisclaimer.SHORT)
    }

    fun endSession(moodAfter: MoodLevel? = null, notes: String? = null) {
        val session = _currentSession.value ?: return
        if (!_isSessionActive.value) return

        session.endTime = System.currentTimeMillis()
        session.moodAfter = moodAfter
        session.notes = notes
        session.duration = session.actualDuration
        session.biofeedback = BiofeedbackSnapshot(
            coherenceLevel = _currentCoherence.value,
            calmness = _currentCalmness.value
        )

        _sessions.value = _sessions.value + session
        _currentSession.value = null
        _isSessionActive.value = false

        updateStatistics()
        updateGoalProgress(session)

        Log.i(TAG, "Completed session. Duration: ${session.durationMinutes} minutes")
    }

    fun cancelSession() {
        _currentSession.value = null
        _isSessionActive.value = false
    }

    // MARK: - Breathing Exercises

    fun startBreathingExercise(pattern: BreathingPattern, onComplete: ((Boolean) -> Unit)? = null) {
        startSession(pattern.name, pattern.category)

        breathingJob?.cancel()
        breathingJob = scope.launch {
            var currentCycle = 0
            var currentPhase = 0 // 0: inhale, 1: hold in, 2: exhale, 3: hold out
            val phases = listOf(
                pattern.inhaleSeconds,
                pattern.holdInSeconds,
                pattern.exhaleSeconds,
                pattern.holdOutSeconds
            )

            while (currentCycle < pattern.cycles) {
                val duration = phases[currentPhase]
                if (duration > 0) {
                    delay((duration * 1000).toLong())
                }

                currentPhase++
                if (currentPhase >= 4) {
                    currentPhase = 0
                    currentCycle++
                }
            }

            endSession()
            onComplete?.invoke(true)
        }
    }

    fun stopBreathingExercise() {
        breathingJob?.cancel()
        breathingJob = null
        if (_isSessionActive.value) {
            endSession()
        }
    }

    // MARK: - Goals

    fun createGoal(
        title: String,
        category: WellnessCategory,
        targetMinutesPerDay: Int = 10,
        targetDaysPerWeek: Int = 5
    ): WellnessGoal {
        val goal = WellnessGoal(
            title = title,
            category = category,
            targetMinutesPerDay = targetMinutesPerDay,
            targetDaysPerWeek = targetDaysPerWeek
        )
        _goals.value = _goals.value + goal
        return goal
    }

    fun deleteGoal(goalId: String) {
        _goals.value = _goals.value.filter { it.id != goalId }
    }

    private fun updateGoalProgress(session: WellnessSession) {
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val minutesCompleted = session.durationMinutes

        _goals.value = _goals.value.map { goal ->
            if (goal.category == session.category && goal.isActive) {
                val existingProgress = goal.progress.find {
                    val calendar = Calendar.getInstance()
                    calendar.timeInMillis = it.date
                    calendar.set(Calendar.HOUR_OF_DAY, 0)
                    calendar.set(Calendar.MINUTE, 0)
                    calendar.set(Calendar.SECOND, 0)
                    calendar.set(Calendar.MILLISECOND, 0)
                    calendar.timeInMillis == today
                }

                if (existingProgress != null) {
                    existingProgress.minutesCompleted += minutesCompleted
                    existingProgress.sessionsCompleted += 1
                } else {
                    goal.progress.add(DailyProgress(
                        date = today,
                        minutesCompleted = minutesCompleted,
                        sessionsCompleted = 1
                    ))
                }
            }
            goal
        }
    }

    // MARK: - Journal

    fun addJournalEntry(title: String, content: String, mood: MoodLevel, tags: List<String> = emptyList()) {
        val entry = JournalEntry(
            title = title,
            content = content,
            mood = mood,
            tags = tags,
            category = _selectedCategory.value
        )
        _journal.value = _journal.value + entry
    }

    fun deleteJournalEntry(entryId: String) {
        _journal.value = _journal.value.filter { it.id != entryId }
    }

    // MARK: - Statistics

    private fun updateStatistics() {
        val allSessions = _sessions.value
        val totalSessions = allSessions.size
        val totalMinutes = allSessions.sumOf { it.durationMinutes }

        // Calculate streaks
        val sortedSessions = allSessions.sortedByDescending { it.startTime }
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 0
        var lastDate: Long? = null

        for (session in sortedSessions) {
            val sessionDate = Calendar.getInstance().apply {
                timeInMillis = session.startTime
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            if (lastDate != null) {
                val dayDiff = ((lastDate!! - sessionDate) / (24 * 60 * 60 * 1000)).toInt()
                if (dayDiff == 1) {
                    tempStreak++
                    longestStreak = maxOf(longestStreak, tempStreak)
                } else if (dayDiff > 1) {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
                val today = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                val daysSince = ((today - sessionDate) / (24 * 60 * 60 * 1000)).toInt()
                if (daysSince <= 1) {
                    currentStreak = tempStreak
                }
            }
            lastDate = sessionDate
        }

        // Calculate favorite category
        val categoryCounts = allSessions.groupBy { it.category }.mapValues { it.value.size }
        val favoriteCategory = categoryCounts.maxByOrNull { it.value }?.key

        // Calculate mood changes
        val moodBeforeValues = allSessions.mapNotNull { it.moodBefore?.value }
        val moodAfterValues = allSessions.mapNotNull { it.moodAfter?.value }
        val avgBefore = if (moodBeforeValues.isEmpty()) 3.0 else moodBeforeValues.average()
        val avgAfter = if (moodAfterValues.isEmpty()) 3.0 else moodAfterValues.average()

        // Weekly minutes
        val weeklyMinutes = MutableList(7) { 0 }
        val calendar = Calendar.getInstance()
        val today = calendar.apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        for (session in allSessions) {
            val sessionDate = Calendar.getInstance().apply {
                timeInMillis = session.startTime
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val dayIndex = ((today - sessionDate) / (24 * 60 * 60 * 1000)).toInt()
            if (dayIndex in 0..6) {
                weeklyMinutes[6 - dayIndex] += session.durationMinutes
            }
        }

        _statistics.value = WellnessStatistics(
            totalSessions = totalSessions,
            totalMinutes = totalMinutes,
            currentStreak = currentStreak,
            longestStreak = maxOf(longestStreak, currentStreak),
            favoriteCategory = favoriteCategory,
            averageMoodBefore = avgBefore,
            averageMoodAfter = avgAfter,
            moodImprovement = avgAfter - avgBefore,
            weeklyMinutes = weeklyMinutes
        )
    }

    // MARK: - Recommendations

    fun getRecommendations(): List<WellnessRecommendation> {
        val recommendations = mutableListOf<WellnessRecommendation>()

        // Based on time of day
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (hour < 10) {
            recommendations.add(WellnessRecommendation(
                title = "Morning Mindfulness",
                description = "Start your day with a brief mindfulness practice",
                category = WellnessCategory.MINDFULNESS,
                duration = 300000
            ))
        } else if (hour > 21) {
            recommendations.add(WellnessRecommendation(
                title = "Evening Wind Down",
                description = "Prepare for restful sleep with relaxation",
                category = WellnessCategory.SLEEP_SUPPORT,
                duration = 600000
            ))
        }

        // Based on current coherence
        if (_currentCoherence.value < 0.4f) {
            recommendations.add(WellnessRecommendation(
                title = "Calming Breath",
                description = "Try some calming breathing exercises",
                category = WellnessCategory.BREATHWORK,
                duration = 300000
            ))
        }

        // Based on statistics
        val stats = _statistics.value
        if (stats.currentStreak > 0) {
            recommendations.add(WellnessRecommendation(
                title = "Keep Your Streak!",
                description = "You're on a ${stats.currentStreak}-day streak. Keep it going!",
                category = stats.favoriteCategory ?: WellnessCategory.RELAXATION,
                duration = 600000
            ))
        }

        return recommendations
    }

    // MARK: - Cleanup

    fun shutdown() {
        biofeedbackJob?.cancel()
        breathingJob?.cancel()
        scope.cancel()
        Log.i(TAG, "Wellness engine shutdown")
    }
}
