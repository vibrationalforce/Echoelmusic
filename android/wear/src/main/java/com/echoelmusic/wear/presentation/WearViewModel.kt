/**
 * WearViewModel.kt
 * Echoelmusic Wear OS ViewModel
 *
 * Manages bio data, sessions, and phone communication
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.wear.presentation

import android.app.Application
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.wearable.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

// ============================================================================
// MARK: - Data Classes
// ============================================================================

data class BioData(
    val heartRate: Int = 72,
    val hrv: Float = 45f,
    val coherence: Float = 0.5f,
    val coherenceLevel: CoherenceLevel = CoherenceLevel.MEDIUM,
    val breathPhase: Float = 0f,
    val breathingRate: Float = 6f,
    val timestamp: Long = System.currentTimeMillis()
)

enum class CoherenceLevel(val displayName: String, val color: Color) {
    LOW("Low", Color(0xFFFF5722)),
    MEDIUM("Medium", Color(0xFFFFC107)),
    HIGH("High", Color(0xFF4CAF50))
}

enum class SessionState {
    IDLE, RUNNING, PAUSED
}

data class WearSettings(
    val hapticFeedback: Boolean = true,
    val alwaysOnDisplay: Boolean = false,
    val showBreathingGuide: Boolean = true,
    val targetDurationMinutes: Int = 10
)

data class SessionSummary(
    val id: String = UUID.randomUUID().toString(),
    val startTime: Long = System.currentTimeMillis(),
    val durationSeconds: Long = 0,
    val avgCoherence: Float = 0f,
    val avgHrv: Float = 0f,
    val peakCoherence: Float = 0f,
    val coherenceLevel: CoherenceLevel = CoherenceLevel.MEDIUM
) {
    val formattedDate: String
        get() {
            val sdf = SimpleDateFormat("MMM d, HH:mm", Locale.getDefault())
            return sdf.format(Date(startTime))
        }
}

// ============================================================================
// MARK: - ViewModel
// ============================================================================

class WearViewModel(application: Application) : AndroidViewModel(application),
    DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener {

    // State flows
    private val _bioData = MutableStateFlow(BioData())
    val bioData: StateFlow<BioData> = _bioData.asStateFlow()

    private val _sessionState = MutableStateFlow(SessionState.IDLE)
    val sessionState: StateFlow<SessionState> = _sessionState.asStateFlow()

    private val _sessionDuration = MutableStateFlow(0L)
    val sessionDuration: StateFlow<Long> = _sessionDuration.asStateFlow()

    private val _isPhoneConnected = MutableStateFlow(false)
    val isPhoneConnected: StateFlow<Boolean> = _isPhoneConnected.asStateFlow()

    private val _settings = MutableStateFlow(WearSettings())
    val settings: StateFlow<WearSettings> = _settings.asStateFlow()

    private val _sessionHistory = MutableStateFlow<List<SessionSummary>>(emptyList())
    val sessionHistory: StateFlow<List<SessionSummary>> = _sessionHistory.asStateFlow()

    // Wearable clients
    private val dataClient: DataClient = Wearable.getDataClient(application)
    private val messageClient: MessageClient = Wearable.getMessageClient(application)
    private val nodeClient: NodeClient = Wearable.getNodeClient(application)

    // Session tracking
    private var sessionStartTime: Long = 0
    private var sessionCoherenceReadings = Collections.synchronizedList(mutableListOf<Float>())
    private var sessionHrvReadings = Collections.synchronizedList(mutableListOf<Float>())
    private var timerJob: kotlinx.coroutines.Job? = null

    // Vibrator for haptic feedback
    private val vibrator: Vibrator? = application.getSystemService(Vibrator::class.java)

    init {
        dataClient.addListener(this)
        messageClient.addListener(this)
        checkPhoneConnection()
        loadSessionHistory()
        startBioDataSimulation() // For testing when no phone connected
    }

    override fun onCleared() {
        super.onCleared()
        dataClient.removeListener(this)
        messageClient.removeListener(this)
    }

    // ========================================================================
    // MARK: - Phone Communication
    // ========================================================================

    private fun checkPhoneConnection() {
        viewModelScope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                _isPhoneConnected.value = nodes.isNotEmpty()
            } catch (e: Exception) {
                _isPhoneConnected.value = false
            }
        }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            if (event.type == DataEvent.TYPE_CHANGED) {
                val dataItem = event.dataItem
                when (dataItem.uri.path) {
                    "/bio-data" -> {
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        updateBioDataFromPhone(dataMap)
                    }
                    "/session-sync" -> {
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        syncSessionFromPhone(dataMap)
                    }
                }
            }
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            "/session-start" -> {
                startSession()
            }
            "/session-stop" -> {
                stopSession()
            }
            "/coherence-pulse" -> {
                triggerHapticPulse()
            }
        }
    }

    private fun updateBioDataFromPhone(dataMap: DataMap) {
        val heartRate = dataMap.getInt("heartRate", 72)
        val hrv = dataMap.getFloat("hrv", 45f)
        val coherence = dataMap.getFloat("coherence", 0.5f)
        val breathPhase = dataMap.getFloat("breathPhase", 0f)
        val breathingRate = dataMap.getFloat("breathingRate", 6f)

        val coherenceLevel = when {
            coherence >= 0.7f -> CoherenceLevel.HIGH
            coherence >= 0.4f -> CoherenceLevel.MEDIUM
            else -> CoherenceLevel.LOW
        }

        _bioData.value = BioData(
            heartRate = heartRate,
            hrv = hrv,
            coherence = coherence,
            coherenceLevel = coherenceLevel,
            breathPhase = breathPhase,
            breathingRate = breathingRate
        )

        // Track session readings
        if (_sessionState.value == SessionState.RUNNING) {
            sessionCoherenceReadings.add(coherence)
            sessionHrvReadings.add(hrv)
        }

        // Haptic feedback on high coherence
        if (coherence >= 0.8f && _settings.value.hapticFeedback) {
            triggerHapticPulse()
        }
    }

    private fun syncSessionFromPhone(dataMap: DataMap) {
        val isRunning = dataMap.getBoolean("isRunning", false)
        val duration = dataMap.getLong("duration", 0)

        if (isRunning && _sessionState.value == SessionState.IDLE) {
            startSession()
        } else if (!isRunning && _sessionState.value == SessionState.RUNNING) {
            stopSession()
        }

        _sessionDuration.value = duration
    }

    // ========================================================================
    // MARK: - Session Management
    // ========================================================================

    fun startSession() {
        _sessionState.value = SessionState.RUNNING
        sessionStartTime = System.currentTimeMillis()
        sessionCoherenceReadings.clear()
        sessionHrvReadings.clear()

        // Start timer
        timerJob = viewModelScope.launch {
            while (_sessionState.value == SessionState.RUNNING) {
                _sessionDuration.value = (System.currentTimeMillis() - sessionStartTime) / 1000
                kotlinx.coroutines.delay(1000)
            }
        }

        // Notify phone
        sendMessageToPhone("/session-start", byteArrayOf())

        // Haptic feedback
        if (_settings.value.hapticFeedback) {
            triggerHaptic(VibrationEffect.EFFECT_CLICK)
        }
    }

    fun pauseSession() {
        _sessionState.value = SessionState.PAUSED
        timerJob?.cancel()
        sendMessageToPhone("/session-pause", byteArrayOf())
    }

    fun resumeSession() {
        _sessionState.value = SessionState.RUNNING

        timerJob = viewModelScope.launch {
            while (_sessionState.value == SessionState.RUNNING) {
                _sessionDuration.value++
                kotlinx.coroutines.delay(1000)
            }
        }

        sendMessageToPhone("/session-resume", byteArrayOf())
    }

    fun stopSession() {
        _sessionState.value = SessionState.IDLE
        timerJob?.cancel()

        // Create session summary
        val avgCoherence = if (sessionCoherenceReadings.isNotEmpty()) {
            sessionCoherenceReadings.average().toFloat()
        } else 0f

        val avgHrv = if (sessionHrvReadings.isNotEmpty()) {
            sessionHrvReadings.average().toFloat()
        } else 0f

        val peakCoherence = sessionCoherenceReadings.maxOrNull() ?: 0f

        val coherenceLevel = when {
            avgCoherence >= 0.7f -> CoherenceLevel.HIGH
            avgCoherence >= 0.4f -> CoherenceLevel.MEDIUM
            else -> CoherenceLevel.LOW
        }

        val summary = SessionSummary(
            startTime = sessionStartTime,
            durationSeconds = _sessionDuration.value,
            avgCoherence = avgCoherence,
            avgHrv = avgHrv,
            peakCoherence = peakCoherence,
            coherenceLevel = coherenceLevel
        )

        // Save to history
        val history = _sessionHistory.value.toMutableList()
        history.add(0, summary)
        if (history.size > 20) history.removeLast()
        _sessionHistory.value = history
        saveSessionHistory()

        // Reset duration
        _sessionDuration.value = 0

        // Notify phone
        sendMessageToPhone("/session-stop", byteArrayOf())

        // Completion haptic
        if (_settings.value.hapticFeedback) {
            triggerHaptic(VibrationEffect.EFFECT_DOUBLE_CLICK)
        }
    }

    // ========================================================================
    // MARK: - Settings
    // ========================================================================

    fun updateSettings(newSettings: WearSettings) {
        _settings.value = newSettings
        saveSettings()
    }

    private fun saveSettings() {
        viewModelScope.launch {
            val prefs = getApplication<Application>().getSharedPreferences("wear_settings", 0)
            prefs.edit()
                .putBoolean("hapticFeedback", _settings.value.hapticFeedback)
                .putBoolean("alwaysOnDisplay", _settings.value.alwaysOnDisplay)
                .putBoolean("showBreathingGuide", _settings.value.showBreathingGuide)
                .putInt("targetDurationMinutes", _settings.value.targetDurationMinutes)
                .apply()
        }
    }

    private fun loadSettings() {
        val prefs = getApplication<Application>().getSharedPreferences("wear_settings", 0)
        _settings.value = WearSettings(
            hapticFeedback = prefs.getBoolean("hapticFeedback", true),
            alwaysOnDisplay = prefs.getBoolean("alwaysOnDisplay", false),
            showBreathingGuide = prefs.getBoolean("showBreathingGuide", true),
            targetDurationMinutes = prefs.getInt("targetDurationMinutes", 10)
        )
    }

    // ========================================================================
    // MARK: - Session History
    // ========================================================================

    private fun saveSessionHistory() {
        viewModelScope.launch {
            val prefs = getApplication<Application>().getSharedPreferences("session_history", 0)
            val json = _sessionHistory.value.map { session ->
                "${session.id}|${session.startTime}|${session.durationSeconds}|${session.avgCoherence}|${session.avgHrv}|${session.peakCoherence}|${session.coherenceLevel.name}"
            }.joinToString("\n")
            prefs.edit().putString("history", json).apply()
        }
    }

    private fun loadSessionHistory() {
        val prefs = getApplication<Application>().getSharedPreferences("session_history", 0)
        val json = prefs.getString("history", "") ?: ""

        if (json.isNotBlank()) {
            val sessions = json.split("\n").mapNotNull { line ->
                try {
                    val parts = line.split("|")
                    if (parts.size >= 7) {
                        SessionSummary(
                            id = parts[0],
                            startTime = parts[1].toLongOrNull() ?: 0,
                            durationSeconds = parts[2].toLongOrNull() ?: 0,
                            avgCoherence = parts[3].toFloatOrNull() ?: 0f,
                            avgHrv = parts[4].toFloatOrNull() ?: 0f,
                            peakCoherence = parts[5].toFloatOrNull() ?: 0f,
                            coherenceLevel = try {
                                CoherenceLevel.valueOf(parts[6])
                            } catch (_: IllegalArgumentException) {
                                CoherenceLevel.MEDIUM
                            }
                        )
                    } else null
                } catch (e: Exception) {
                    null
                }
            }
            _sessionHistory.value = sessions
        }
    }

    // ========================================================================
    // MARK: - Haptics
    // ========================================================================

    private fun triggerHaptic(effect: Int) {
        vibrator?.vibrate(VibrationEffect.createPredefined(effect))
    }

    private fun triggerHapticPulse() {
        vibrator?.vibrate(
            VibrationEffect.createWaveform(
                longArrayOf(0, 100, 50, 100),
                intArrayOf(0, 128, 0, 64),
                -1
            )
        )
    }

    // ========================================================================
    // MARK: - Message Sending
    // ========================================================================

    private fun sendMessageToPhone(path: String, data: ByteArray) {
        viewModelScope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                nodes.forEach { node ->
                    messageClient.sendMessage(node.id, path, data).await()
                }
            } catch (e: Exception) {
                // Phone not connected
            }
        }
    }

    // ========================================================================
    // MARK: - Bio Data Simulation (for testing)
    // ========================================================================

    private fun startBioDataSimulation() {
        viewModelScope.launch {
            var phase = 0f
            while (isActive) {
                if (!_isPhoneConnected.value) {
                    // Simulate bio data when phone not connected
                    phase += 0.05f
                    if (phase > 1f) phase = 0f

                    val coherence = (kotlin.math.sin(phase * kotlin.math.PI * 2) + 1) / 2 * 0.5f + 0.25f
                    val hrv = 40f + (kotlin.math.sin(phase * kotlin.math.PI * 4) + 1) * 15f
                    val heartRate = (70 + (kotlin.math.sin(phase * kotlin.math.PI * 2) * 10)).toInt()

                    _bioData.value = BioData(
                        heartRate = heartRate,
                        hrv = hrv,
                        coherence = coherence,
                        coherenceLevel = when {
                            coherence >= 0.7f -> CoherenceLevel.HIGH
                            coherence >= 0.4f -> CoherenceLevel.MEDIUM
                            else -> CoherenceLevel.LOW
                        },
                        breathPhase = phase,
                        breathingRate = 6f
                    )

                    if (_sessionState.value == SessionState.RUNNING) {
                        sessionCoherenceReadings.add(coherence)
                        sessionHrvReadings.add(hrv)
                    }
                }
                kotlinx.coroutines.delay(100)
            }
        }
    }
}

// Extension to await Google Play Services tasks
suspend fun <T> com.google.android.gms.tasks.Task<T>.await(): T {
    return kotlinx.coroutines.tasks.await()
}
