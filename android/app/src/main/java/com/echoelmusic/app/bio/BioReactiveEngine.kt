package com.echoelmusic.app.bio

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Collections

/**
 * Echoelmusic Bio-Reactive Engine
 * Integrates with Health Connect for real-time bio-data
 *
 * Features:
 * - Heart Rate monitoring
 * - HRV (Heart Rate Variability) for coherence
 * - Respiratory rate
 * - Bio-to-audio parameter mapping
 */
class BioReactiveEngine(private val context: Context) {

    companion object {
        private const val TAG = "BioReactiveEngine"

        val REQUIRED_PERMISSIONS = setOf(
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
            HealthPermission.getReadPermission(RespiratoryRateRecord::class)
        )
    }

    private var healthConnectClient: HealthConnectClient? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // State
    private val _heartRate = MutableStateFlow(70f)
    val heartRate: StateFlow<Float> = _heartRate

    private val _hrv = MutableStateFlow(50f) // RMSSD in ms
    val hrv: StateFlow<Float> = _hrv

    private val _coherence = MutableStateFlow(0.5f)
    val coherence: StateFlow<Float> = _coherence

    private val _respiratoryRate = MutableStateFlow(12f)
    val respiratoryRate: StateFlow<Float> = _respiratoryRate

    // Alias for UnifiedControlHub integration (breathing rate is synonymous)
    val breathingRate: StateFlow<Float> = _respiratoryRate

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    // Callbacks
    private var heartRateCallback: ((Float, Float, Float) -> Unit)? = null

    // HRV analysis (thread-safe synchronized list)
    private val hrvWindow: MutableList<Float> = Collections.synchronizedList(mutableListOf())
    private val hrvWindowSize = 60 // 1 minute of data

    init {
        initHealthConnect()
    }

    private fun initHealthConnect() {
        val availability = HealthConnectClient.getSdkStatus(context)

        when (availability) {
            HealthConnectClient.SDK_AVAILABLE -> {
                healthConnectClient = HealthConnectClient.getOrCreate(context)
                _isConnected.value = true
                Log.i(TAG, "Health Connect available and connected")
                startPolling()
            }
            HealthConnectClient.SDK_UNAVAILABLE -> {
                Log.w(TAG, "Health Connect not available on this device")
                startSimulatedData()
            }
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                Log.w(TAG, "Health Connect needs update")
                startSimulatedData()
            }
        }
    }

    fun setHeartRateCallback(callback: (heartRate: Float, hrv: Float, coherence: Float) -> Unit) {
        heartRateCallback = callback
    }

    private fun startPolling() {
        scope.launch {
            while (isActive) {
                try {
                    readHeartRate()
                    readHRV()
                    readRespiratoryRate()
                    calculateCoherence()

                    // Notify callback
                    heartRateCallback?.invoke(
                        _heartRate.value,
                        _hrv.value,
                        _coherence.value
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading health data: ${e.message}")
                }

                delay(1000) // Poll every second
            }
        }
    }

    private suspend fun readHeartRate() {
        val client = healthConnectClient ?: return

        val request = ReadRecordsRequest(
            recordType = HeartRateRecord::class,
            timeRangeFilter = TimeRangeFilter.after(
                Instant.now().minus(1, ChronoUnit.MINUTES)
            )
        )

        try {
            // Add 5-second timeout to prevent ANR
            val response = withTimeoutOrNull(5000) {
                client.readRecords(request)
            }
            response?.records?.lastOrNull()?.let { record ->
                record.samples.lastOrNull()?.let { sample ->
                    _heartRate.value = sample.beatsPerMinute.toFloat()
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Permission denied for heart rate")
        } catch (e: Exception) {
            Log.w(TAG, "Error reading heart rate: ${e.message}")
        }
    }

    private suspend fun readHRV() {
        val client = healthConnectClient ?: return

        val request = ReadRecordsRequest(
            recordType = HeartRateVariabilityRmssdRecord::class,
            timeRangeFilter = TimeRangeFilter.after(
                Instant.now().minus(5, ChronoUnit.MINUTES)
            )
        )

        try {
            // Add 5-second timeout to prevent ANR
            val response = withTimeoutOrNull(5000) {
                client.readRecords(request)
            }
            response?.records?.lastOrNull()?.let { record ->
                val hrvValue = record.heartRateVariabilityMillis.toFloat()
                _hrv.value = hrvValue

                // Add to analysis window
                hrvWindow.add(hrvValue)
                if (hrvWindow.size > hrvWindowSize) {
                    hrvWindow.removeAt(0)
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Permission denied for HRV")
        } catch (e: Exception) {
            Log.w(TAG, "Error reading HRV: ${e.message}")
        }
    }

    private suspend fun readRespiratoryRate() {
        val client = healthConnectClient ?: return

        val request = ReadRecordsRequest(
            recordType = RespiratoryRateRecord::class,
            timeRangeFilter = TimeRangeFilter.after(
                Instant.now().minus(5, ChronoUnit.MINUTES)
            )
        )

        try {
            // Add 5-second timeout to prevent ANR
            val response = withTimeoutOrNull(5000) {
                client.readRecords(request)
            }
            response?.records?.lastOrNull()?.let { record ->
                _respiratoryRate.value = record.rate.toFloat()
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Permission denied for respiratory rate")
        } catch (e: Exception) {
            Log.w(TAG, "Error reading respiratory rate: ${e.message}")
        }
    }

    /**
     * Calculate coherence based on HRV patterns
     * Uses HRV power spectral analysis principles:
     * - High coherence: Regular, sine-wave-like HRV pattern
     * - Low coherence: Irregular, chaotic HRV pattern
     */
    private fun calculateCoherence() {
        if (hrvWindow.size < 10) {
            _coherence.value = 0.5f
            return
        }

        // Calculate variance (indicator of HRV health)
        val mean = hrvWindow.average().toFloat()
        val variance = hrvWindow.map { (it - mean) * (it - mean) }.average().toFloat()
        val stdDev = kotlin.math.sqrt(variance)

        // Calculate coefficient of variation
        val cv = if (mean > 0) stdDev / mean else 0f

        // Estimate coherence from regularity
        // Low CV with healthy HRV range (20-100ms) = high coherence
        val healthyRange = _hrv.value in 20f..100f
        val regularPattern = cv < 0.3f

        _coherence.value = when {
            healthyRange && regularPattern -> 0.8f + (1 - cv) * 0.2f
            healthyRange -> 0.5f + (1 - cv) * 0.3f
            else -> 0.3f * (1 - cv.coerceAtMost(1f))
        }.coerceIn(0f, 1f)
    }

    /**
     * Start simulated bio data when Health Connect is unavailable
     */
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
                _hrv.value = (baseHRV + hrvVariation).coerceIn(20f, 100f)

                // Simulate coherence
                val coherenceBase = 0.5f
                val coherenceVar = (kotlin.math.sin(phase * 0.02) * 0.3f).toFloat()
                _coherence.value = (coherenceBase + coherenceVar).coerceIn(0f, 1f)

                // Respiratory rate
                _respiratoryRate.value = 12f + (kotlin.math.sin(phase * 0.01) * 3f).toFloat()

                // Notify callback
                heartRateCallback?.invoke(
                    _heartRate.value,
                    _hrv.value,
                    _coherence.value
                )

                phase += 0.1
                delay(100) // 10Hz update
            }
        }
    }

    fun shutdown() {
        scope.cancel()
        // Clear callback to prevent memory leaks
        heartRateCallback = null
        hrvWindow.clear()
        Log.i(TAG, "BioReactiveEngine shutdown complete")
    }

    fun clearCallback() {
        heartRateCallback = null
    }
}
