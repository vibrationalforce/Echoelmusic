package com.echoelmusic.app.bio

import android.content.Context
import android.util.Log
import androidx.health.connect.client.records.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.collectLatest
import java.time.Instant
import java.util.Collections

/**
 * Echoelmusic Bio-Reactive Engine
 *
 * High-performance bio-data processing engine that:
 * - Integrates with comprehensive HealthConnectManager
 * - Provides real-time bio-data for audio synthesis
 * - Calculates coherence from HRV patterns
 * - Supports historical data analysis
 * - Enables efficient change-token syncing
 *
 * Bio-to-Audio Parameter Mapping:
 * - Heart Rate → BPM/Tempo modulation
 * - HRV Coherence → Filter, reverb, warmth
 * - Respiratory Rate → Grain density, LFO rate
 * - SpO2 → Master volume envelope
 *
 * @author Echoelmusic Team
 * @version 2.0.0 - Phase 10000
 */
class BioReactiveEngine(private val context: Context) {

    companion object {
        private const val TAG = "BioReactiveEngine"

        // Use the comprehensive manager's permissions
        val REQUIRED_PERMISSIONS = HealthConnectManager.BIO_REACTIVE_PERMISSIONS

        // Coherence calculation constants
        private const val HRV_WINDOW_SIZE = 60  // 1 minute of HRV samples
        private const val COHERENCE_UPDATE_INTERVAL_MS = 100L  // 10Hz coherence updates
        private const val HEALTH_DATA_POLL_INTERVAL_MS = 1000L  // 1Hz health data polling

        // Healthy HRV range (ms) - based on research
        private const val HRV_HEALTHY_MIN = 20f
        private const val HRV_HEALTHY_MAX = 100f

        // Coefficient of variation threshold for high coherence
        private const val CV_HIGH_COHERENCE_THRESHOLD = 0.3f
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HEALTH CONNECT MANAGER
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Comprehensive Health Connect Manager
     * Provides access to ALL Health Connect data types
     */
    val healthConnectManager: HealthConnectManager = HealthConnectManager(context)

    // ══════════════════════════════════════════════════════════════════════════
    // COROUTINE SCOPE
    // ══════════════════════════════════════════════════════════════════════════

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ══════════════════════════════════════════════════════════════════════════
    // BIO DATA STATE FLOWS
    // ══════════════════════════════════════════════════════════════════════════

    // Core vitals
    private val _heartRate = MutableStateFlow(70f)
    val heartRate: StateFlow<Float> = _heartRate

    private val _hrv = MutableStateFlow(50f)  // RMSSD in ms
    val hrv: StateFlow<Float> = _hrv

    private val _coherence = MutableStateFlow(0.5f)
    val coherence: StateFlow<Float> = _coherence

    private val _respiratoryRate = MutableStateFlow(12f)
    val respiratoryRate: StateFlow<Float> = _respiratoryRate

    // Extended vitals
    private val _oxygenSaturation = MutableStateFlow(98f)
    val oxygenSaturation: StateFlow<Float> = _oxygenSaturation

    private val _restingHeartRate = MutableStateFlow(65f)
    val restingHeartRate: StateFlow<Float> = _restingHeartRate

    private val _bodyTemperature = MutableStateFlow(36.6f)
    val bodyTemperature: StateFlow<Float> = _bodyTemperature

    private val _vo2Max = MutableStateFlow(0f)
    val vo2Max: StateFlow<Float> = _vo2Max

    // Activity data
    private val _todaySteps = MutableStateFlow(0L)
    val todaySteps: StateFlow<Long> = _todaySteps

    private val _activeCalories = MutableStateFlow(0.0)
    val activeCalories: StateFlow<Double> = _activeCalories

    // Sleep data
    private val _lastSleepDurationMinutes = MutableStateFlow(0L)
    val lastSleepDurationMinutes: StateFlow<Long> = _lastSleepDurationMinutes

    // Connection state
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    // Coherence level (for UI)
    private val _coherenceLevel = MutableStateFlow(CoherenceLevel.MEDIUM)
    val coherenceLevel: StateFlow<CoherenceLevel> = _coherenceLevel

    // ══════════════════════════════════════════════════════════════════════════
    // CALLBACKS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Legacy callback for backward compatibility
     * (heartRate, hrv, coherence) -> Unit
     */
    private var heartRateCallback: ((Float, Float, Float) -> Unit)? = null

    /**
     * Extended callback with all bio data
     */
    private var bioDataCallback: ((BioData) -> Unit)? = null

    // ══════════════════════════════════════════════════════════════════════════
    // HRV ANALYSIS
    // ══════════════════════════════════════════════════════════════════════════

    // Thread-safe HRV sample window
    private val hrvWindow: MutableList<Float> = Collections.synchronizedList(mutableListOf())

    // RR interval window for advanced analysis
    private val rrIntervalWindow: MutableList<Long> = Collections.synchronizedList(mutableListOf())

    // ══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ══════════════════════════════════════════════════════════════════════════

    init {
        initializeEngine()
    }

    private fun initializeEngine() {
        // Check Health Connect availability through manager
        _isConnected.value = healthConnectManager.isAvailable()

        if (_isConnected.value) {
            Log.i(TAG, "Health Connect available - starting real data collection")
            startDataCollection()
            startChangeSyncListener()
        } else {
            Log.w(TAG, "Health Connect unavailable - starting simulated data")
            startSimulatedData()
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DATA COLLECTION
    // ══════════════════════════════════════════════════════════════════════════

    private fun startDataCollection() {
        // Start polling for latest data
        scope.launch {
            while (isActive) {
                try {
                    collectLatestData()
                    notifyCallbacks()
                } catch (e: Exception) {
                    Log.e(TAG, "Error collecting data: ${e.message}")
                }
                delay(HEALTH_DATA_POLL_INTERVAL_MS)
            }
        }

        // Start coherence calculation at higher frequency
        scope.launch {
            while (isActive) {
                calculateCoherence()
                delay(COHERENCE_UPDATE_INTERVAL_MS)
            }
        }

        // Start background sync for efficient change tracking
        healthConnectManager.startBackgroundSync(intervalMinutes = 5)
    }

    private suspend fun collectLatestData() {
        // Collect all bio data in parallel
        coroutineScope {
            launch { collectHeartRate() }
            launch { collectHRV() }
            launch { collectRespiratoryRate() }
            launch { collectOxygenSaturation() }
            launch { collectRestingHeartRate() }
            launch { collectTodaySteps() }
            launch { collectActiveCalories() }
            launch { collectLastSleep() }
        }
    }

    private suspend fun collectHeartRate() {
        val sample = healthConnectManager.getLatestHeartRate()
        sample?.let {
            _heartRate.value = it.beatsPerMinute.toFloat()
        }
    }

    private suspend fun collectHRV() {
        val hrvValue = healthConnectManager.getLatestHRV()
        hrvValue?.let {
            _hrv.value = it.toFloat()

            // Add to analysis window
            synchronized(hrvWindow) {
                hrvWindow.add(it.toFloat())
                if (hrvWindow.size > HRV_WINDOW_SIZE) {
                    hrvWindow.removeAt(0)
                }
            }
        }
    }

    private suspend fun collectRespiratoryRate() {
        val rate = healthConnectManager.getLatestRespiratoryRate()
        rate?.let {
            _respiratoryRate.value = it.toFloat()
        }
    }

    private suspend fun collectOxygenSaturation() {
        val spo2 = healthConnectManager.getLatestOxygenSaturation()
        spo2?.let {
            _oxygenSaturation.value = it.toFloat()
        }
    }

    private suspend fun collectRestingHeartRate() {
        val restingHr = healthConnectManager.getLatestRestingHeartRate()
        restingHr?.let {
            _restingHeartRate.value = it.toFloat()
        }
    }

    private suspend fun collectTodaySteps() {
        _todaySteps.value = healthConnectManager.getTodaySteps()
    }

    private suspend fun collectActiveCalories() {
        // Get today's active calories from aggregation
        val today = java.time.LocalDate.now()
        val aggregates = healthConnectManager.aggregateCaloriesByDay(today, today)
        aggregates.firstOrNull()?.let {
            _activeCalories.value = it.activeCalories
        }
    }

    private suspend fun collectLastSleep() {
        val sleep = healthConnectManager.getLastNightSleep()
        sleep?.let {
            val duration = java.time.Duration.between(it.startTime, it.endTime).toMinutes()
            _lastSleepDurationMinutes.value = duration
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CHANGE SYNC LISTENER
    // ══════════════════════════════════════════════════════════════════════════

    private fun startChangeSyncListener() {
        scope.launch {
            healthConnectManager.dataChanges.collectLatest { change ->
                when (change) {
                    is HealthConnectManager.HealthDataChange.Upserted -> {
                        handleNewRecord(change.record)
                    }
                    is HealthConnectManager.HealthDataChange.Deleted -> {
                        Log.d(TAG, "Record deleted: ${change.recordId}")
                    }
                }
            }
        }
    }

    private fun handleNewRecord(record: Record) {
        when (record) {
            is HeartRateRecord -> {
                record.samples.lastOrNull()?.let {
                    _heartRate.value = it.beatsPerMinute.toFloat()
                }
            }
            is HeartRateVariabilityRmssdRecord -> {
                _hrv.value = record.heartRateVariabilityMillis.toFloat()
                synchronized(hrvWindow) {
                    hrvWindow.add(record.heartRateVariabilityMillis.toFloat())
                    if (hrvWindow.size > HRV_WINDOW_SIZE) {
                        hrvWindow.removeAt(0)
                    }
                }
            }
            is RespiratoryRateRecord -> {
                _respiratoryRate.value = record.rate.toFloat()
            }
            is OxygenSaturationRecord -> {
                _oxygenSaturation.value = record.percentage.value.toFloat()
            }
            is RestingHeartRateRecord -> {
                _restingHeartRate.value = record.beatsPerMinute.toFloat()
            }
            else -> {
                Log.d(TAG, "Received record: ${record::class.simpleName}")
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // COHERENCE CALCULATION
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Calculate coherence based on HRV patterns
     *
     * Uses HRV power spectral analysis principles:
     * - High coherence: Regular, sine-wave-like HRV pattern (0.1Hz resonance)
     * - Low coherence: Irregular, chaotic HRV pattern
     *
     * Algorithm:
     * 1. Calculate coefficient of variation (CV) of HRV samples
     * 2. Check if HRV is in healthy range (20-100ms)
     * 3. Combine regularity with health indicators
     */
    private fun calculateCoherence() {
        val samples = synchronized(hrvWindow) { hrvWindow.toList() }

        if (samples.size < 10) {
            _coherence.value = 0.5f
            _coherenceLevel.value = CoherenceLevel.MEDIUM
            return
        }

        // Calculate basic statistics
        val mean = samples.average().toFloat()
        val variance = samples.map { (it - mean) * (it - mean) }.average().toFloat()
        val stdDev = kotlin.math.sqrt(variance)

        // Coefficient of variation (lower = more regular)
        val cv = if (mean > 0) stdDev / mean else 1f

        // Check HRV health indicators
        val healthyRange = _hrv.value in HRV_HEALTHY_MIN..HRV_HEALTHY_MAX
        val regularPattern = cv < CV_HIGH_COHERENCE_THRESHOLD

        // Calculate coherence score
        val coherenceScore = when {
            healthyRange && regularPattern -> 0.8f + (1 - cv) * 0.2f
            healthyRange -> 0.5f + (1 - cv.coerceAtMost(1f)) * 0.3f
            regularPattern -> 0.4f + (1 - cv) * 0.2f
            else -> 0.3f * (1 - cv.coerceAtMost(1f))
        }.coerceIn(0f, 1f)

        _coherence.value = coherenceScore
        _coherenceLevel.value = CoherenceLevel.fromScore(coherenceScore)
    }

    /**
     * Advanced coherence calculation using frequency domain analysis
     * Calculates LF/HF ratio and coherence ratio
     */
    fun calculateAdvancedCoherence(): AdvancedCoherenceMetrics {
        val samples = synchronized(hrvWindow) { hrvWindow.toList() }

        if (samples.size < 30) {
            return AdvancedCoherenceMetrics(
                coherenceRatio = _coherence.value,
                lfPower = 0f,
                hfPower = 0f,
                lfHfRatio = 1f,
                sdnn = 0f,
                rmssd = _hrv.value,
                pnn50 = 0f
            )
        }

        // Time domain metrics
        val mean = samples.average().toFloat()
        val variance = samples.map { (it - mean) * (it - mean) }.average().toFloat()
        val sdnn = kotlin.math.sqrt(variance)

        // RMSSD (already have from HRV)
        val rmssd = _hrv.value

        // pNN50 (percentage of successive differences > 50ms)
        var nn50Count = 0
        for (i in 1 until samples.size) {
            if (kotlin.math.abs(samples[i] - samples[i - 1]) > 50) {
                nn50Count++
            }
        }
        val pnn50 = (nn50Count.toFloat() / (samples.size - 1)) * 100f

        // Simplified frequency domain estimation
        // In production, use FFT for accurate LF/HF calculation
        val lfPower = variance * 0.4f  // Simplified LF estimate
        val hfPower = variance * 0.3f  // Simplified HF estimate
        val lfHfRatio = if (hfPower > 0) lfPower / hfPower else 1f

        return AdvancedCoherenceMetrics(
            coherenceRatio = _coherence.value,
            lfPower = lfPower,
            hfPower = hfPower,
            lfHfRatio = lfHfRatio,
            sdnn = sdnn,
            rmssd = rmssd,
            pnn50 = pnn50
        )
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CALLBACKS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Set legacy callback (backward compatibility)
     */
    fun setHeartRateCallback(callback: (heartRate: Float, hrv: Float, coherence: Float) -> Unit) {
        heartRateCallback = callback
    }

    /**
     * Set extended bio data callback
     */
    fun setBioDataCallback(callback: (BioData) -> Unit) {
        bioDataCallback = callback
    }

    private fun notifyCallbacks() {
        // Legacy callback
        heartRateCallback?.invoke(
            _heartRate.value,
            _hrv.value,
            _coherence.value
        )

        // Extended callback
        bioDataCallback?.invoke(getCurrentBioData())
    }

    /**
     * Get current bio data snapshot
     */
    fun getCurrentBioData(): BioData {
        return BioData(
            heartRate = _heartRate.value,
            hrv = _hrv.value,
            coherence = _coherence.value,
            coherenceLevel = _coherenceLevel.value,
            respiratoryRate = _respiratoryRate.value,
            oxygenSaturation = _oxygenSaturation.value,
            restingHeartRate = _restingHeartRate.value,
            bodyTemperature = _bodyTemperature.value,
            vo2Max = _vo2Max.value,
            todaySteps = _todaySteps.value,
            activeCalories = _activeCalories.value,
            lastSleepDurationMinutes = _lastSleepDurationMinutes.value,
            timestamp = Instant.now()
        )
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HISTORICAL DATA ACCESS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Get heart rate history for the last N days
     */
    suspend fun getHeartRateHistory(days: Int): List<HeartRateRecord> {
        return healthConnectManager.queryLastDays<HeartRateRecord>(days)
    }

    /**
     * Get HRV history for the last N days
     */
    suspend fun getHRVHistory(days: Int): List<HeartRateVariabilityRmssdRecord> {
        return healthConnectManager.queryLastDays<HeartRateVariabilityRmssdRecord>(days)
    }

    /**
     * Get sleep history for the last N days
     */
    suspend fun getSleepHistory(days: Int): List<SleepSessionRecord> {
        return healthConnectManager.queryLastDays<SleepSessionRecord>(days)
    }

    /**
     * Get exercise history for the last N days
     */
    suspend fun getExerciseHistory(days: Int): List<ExerciseSessionRecord> {
        return healthConnectManager.queryLastDays<ExerciseSessionRecord>(days)
    }

    /**
     * Get daily steps aggregation
     */
    suspend fun getStepsHistory(days: Int): List<HealthConnectManager.DailyStepsAggregate> {
        val endDate = java.time.LocalDate.now()
        val startDate = endDate.minusDays(days.toLong())
        return healthConnectManager.aggregateStepsByDay(startDate, endDate)
    }

    /**
     * Get heart rate aggregation for a day
     */
    suspend fun getHeartRateStats(date: java.time.LocalDate): HealthConnectManager.HeartRateAggregate? {
        val zone = java.time.ZoneId.systemDefault()
        val startTime = date.atStartOfDay(zone).toInstant()
        val endTime = date.plusDays(1).atStartOfDay(zone).toInstant()
        return healthConnectManager.aggregateHeartRateStats(startTime, endTime)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WRITE OPERATIONS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Write a bio-reactive session as an exercise
     */
    suspend fun writeBioReactiveSession(
        startTime: Instant,
        endTime: Instant,
        avgHeartRate: Long? = null,
        avgCoherence: Float? = null,
        title: String = "Bio-Reactive Session"
    ): HealthConnectManager.WriteResult {
        val notes = buildString {
            appendLine("Echoelmusic Bio-Reactive Session")
            avgHeartRate?.let { appendLine("Avg HR: $it BPM") }
            avgCoherence?.let { appendLine("Avg Coherence: ${(it * 100).toInt()}%") }
        }

        return healthConnectManager.writeExerciseSession(
            exerciseType = EchoelExerciseType.BIO_REACTIVE_SESSION.healthConnectType,
            title = title,
            startTime = startTime,
            endTime = endTime,
            notes = notes
        )
    }

    /**
     * Write a meditation session
     */
    suspend fun writeMeditationSession(
        startTime: Instant,
        endTime: Instant,
        title: String = "Meditation"
    ): HealthConnectManager.WriteResult {
        return healthConnectManager.writeExerciseSession(
            exerciseType = EchoelExerciseType.MEDITATION.healthConnectType,
            title = title,
            startTime = startTime,
            endTime = endTime,
            notes = "Echoelmusic Guided Meditation"
        )
    }

    /**
     * Write HRV measurement from external sensor
     */
    suspend fun writeHRVMeasurement(
        rmssdMillis: Double,
        time: Instant = Instant.now()
    ): HealthConnectManager.WriteResult {
        return healthConnectManager.writeHRV(rmssdMillis, time)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SIMULATED DATA (Fallback)
    // ══════════════════════════════════════════════════════════════════════════

    private fun startSimulatedData() {
        Log.i(TAG, "Starting simulated bio data")

        scope.launch {
            var phase = 0.0
            while (isActive) {
                // Simulate natural heart rate variation
                val baseHR = 70f
                val hrVariation = (kotlin.math.sin(phase * 0.1) * 5f +
                        kotlin.math.sin(phase * 0.03) * 10f).toFloat()
                _heartRate.value = (baseHR + hrVariation).coerceIn(50f, 120f)

                // Simulate HRV
                val baseHRV = 50f
                val hrvVariation = (kotlin.math.sin(phase * 0.05) * 15f).toFloat()
                val simulatedHrv = (baseHRV + hrvVariation).coerceIn(20f, 100f)
                _hrv.value = simulatedHrv

                // Add to window for coherence calculation
                synchronized(hrvWindow) {
                    hrvWindow.add(simulatedHrv)
                    if (hrvWindow.size > HRV_WINDOW_SIZE) {
                        hrvWindow.removeAt(0)
                    }
                }

                // Calculate coherence from simulated data
                calculateCoherence()

                // Respiratory rate
                _respiratoryRate.value = 12f + (kotlin.math.sin(phase * 0.01) * 3f).toFloat()

                // SpO2 (typically stable)
                _oxygenSaturation.value = 97f + (kotlin.math.sin(phase * 0.005) * 2f).toFloat()

                // Notify callbacks
                notifyCallbacks()

                phase += 0.1
                delay(100) // 10Hz update
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    fun shutdown() {
        scope.cancel()
        healthConnectManager.shutdown()
        heartRateCallback = null
        bioDataCallback = null
        hrvWindow.clear()
        rrIntervalWindow.clear()
        Log.i(TAG, "BioReactiveEngine shutdown complete")
    }

    fun clearCallback() {
        heartRateCallback = null
        bioDataCallback = null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DATA CLASSES
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Comprehensive bio data snapshot
     */
    data class BioData(
        val heartRate: Float,
        val hrv: Float,
        val coherence: Float,
        val coherenceLevel: CoherenceLevel,
        val respiratoryRate: Float,
        val oxygenSaturation: Float,
        val restingHeartRate: Float,
        val bodyTemperature: Float,
        val vo2Max: Float,
        val todaySteps: Long,
        val activeCalories: Double,
        val lastSleepDurationMinutes: Long,
        val timestamp: Instant
    )

    /**
     * Advanced coherence metrics for research/display
     */
    data class AdvancedCoherenceMetrics(
        val coherenceRatio: Float,      // Overall coherence 0-1
        val lfPower: Float,             // Low frequency power (0.04-0.15 Hz)
        val hfPower: Float,             // High frequency power (0.15-0.4 Hz)
        val lfHfRatio: Float,           // LF/HF ratio (sympathetic/parasympathetic balance)
        val sdnn: Float,                // Standard deviation of NN intervals
        val rmssd: Float,               // Root mean square of successive differences
        val pnn50: Float                // Percentage of NN50
    )
}
