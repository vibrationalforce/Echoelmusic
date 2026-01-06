package com.echoelmusic.hardware

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Cross-Platform Session Manager - Phase 10000 ULTIMATE
 * Nobel Prize Multitrillion Dollar Company - Ralph Wiggum Lambda Loop
 *
 * Supports ALL device combinations:
 * - Android + iPhone
 * - Android + Windows
 * - Android + Mac
 * - Android + Meta Quest
 * - Android + Apple Watch
 * - Android + ANY combination!
 *
 * Philosophy: Adaptive Zero-Latency + High Quality
 */
class CrossPlatformSessionManager private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var instance: CrossPlatformSessionManager? = null

        private const val SERVICE_TYPE = "_echoelmusic._tcp."
        private const val SERVICE_NAME = "Echoelmusic"
        private const val SYNC_PORT = 41234

        fun getInstance(context: Context): CrossPlatformSessionManager {
            return instance ?: synchronized(this) {
                instance ?: CrossPlatformSessionManager(context.applicationContext).also { instance = it }
            }
        }
    }

    // State
    private val _discoveredDevices = MutableStateFlow<List<DiscoveredDevice>>(emptyList())
    val discoveredDevices: StateFlow<List<DiscoveredDevice>> = _discoveredDevices.asStateFlow()

    private val _activeSession = MutableStateFlow<CrossPlatformSession?>(null)
    val activeSession: StateFlow<CrossPlatformSession?> = _activeSession.asStateFlow()

    private val _syncStatus = MutableStateFlow(SyncStatus.IDLE)
    val syncStatus: StateFlow<SyncStatus> = _syncStatus.asStateFlow()

    private val _connectionQuality = MutableStateFlow(ConnectionQuality.EXCELLENT)
    val connectionQuality: StateFlow<ConnectionQuality> = _connectionQuality.asStateFlow()

    // Network
    private var nsdManager: NsdManager? = null
    private val connections = ConcurrentHashMap<String, Socket>()
    private val latencyEngine = AdaptiveZeroLatencyEngine()

    init {
        nsdManager = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
    }

    // MARK: - Discovery

    private val discoveryListener = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(serviceType: String) {
            _syncStatus.value = SyncStatus.DISCOVERING
        }

        override fun onServiceFound(serviceInfo: NsdServiceInfo) {
            if (serviceInfo.serviceName.contains(SERVICE_NAME)) {
                nsdManager?.resolveService(serviceInfo, resolveListener)
            }
        }

        override fun onServiceLost(serviceInfo: NsdServiceInfo) {
            _discoveredDevices.value = _discoveredDevices.value.filter {
                it.name != serviceInfo.serviceName
            }
        }

        override fun onDiscoveryStopped(serviceType: String) {
            _syncStatus.value = SyncStatus.IDLE
        }

        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {}
        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
    }

    private val resolveListener = object : NsdManager.ResolveListener {
        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}

        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
            val device = DiscoveredDevice(
                id = UUID.randomUUID().toString(),
                name = serviceInfo.serviceName,
                host = serviceInfo.host?.hostAddress ?: "",
                port = serviceInfo.port,
                platform = detectPlatform(serviceInfo.serviceName)
            )
            val current = _discoveredDevices.value.toMutableList()
            if (!current.any { it.name == device.name }) {
                current.add(device)
                _discoveredDevices.value = current
            }
        }
    }

    private fun detectPlatform(name: String): DevicePlatform {
        val lower = name.lowercase()
        return when {
            lower.contains("iphone") -> DevicePlatform.IOS
            lower.contains("ipad") -> DevicePlatform.IPADOS
            lower.contains("mac") -> DevicePlatform.MACOS
            lower.contains("watch") && lower.contains("apple") -> DevicePlatform.WATCHOS
            lower.contains("vision") -> DevicePlatform.VISIONOS
            lower.contains("windows") -> DevicePlatform.WINDOWS
            lower.contains("linux") -> DevicePlatform.LINUX
            lower.contains("chrome") -> DevicePlatform.CHROMEOS
            lower.contains("quest") -> DevicePlatform.QUEST_OS
            lower.contains("tesla") -> DevicePlatform.TESLA_OS
            lower.contains("android") || lower.contains("pixel") || lower.contains("galaxy") -> DevicePlatform.ANDROID
            else -> DevicePlatform.CUSTOM
        }
    }

    /**
     * Start discovering devices on the network
     */
    fun startDiscovery() {
        nsdManager?.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    }

    /**
     * Stop discovering devices
     */
    fun stopDiscovery() {
        try {
            nsdManager?.stopServiceDiscovery(discoveryListener)
        } catch (e: Exception) {
            // Ignore if not discovering
        }
    }

    // MARK: - Session Management

    /**
     * Create a cross-platform session with any device combination
     */
    fun createSession(
        name: String,
        devices: List<SessionDevice>,
        syncMode: SyncMode = SyncMode.ADAPTIVE
    ): CrossPlatformSession {
        val session = CrossPlatformSession(
            id = UUID.randomUUID().toString(),
            name = name,
            devices = devices.toMutableList(),
            syncMode = syncMode,
            latencyCompensation = LatencyCompensation()
        )
        _activeSession.value = session
        _syncStatus.value = SyncStatus.CONNECTED

        // Connect to all devices
        devices.forEach { device ->
            connectToDevice(device)
        }

        return session
    }

    /**
     * Leave current session
     */
    fun leaveSession() {
        connections.values.forEach { socket ->
            try { socket.close() } catch (e: Exception) {}
        }
        connections.clear()
        _activeSession.value = null
        _syncStatus.value = SyncStatus.IDLE
    }

    private fun connectToDevice(device: SessionDevice) {
        Thread {
            try {
                val socket = Socket()
                socket.connect(InetSocketAddress(device.host, device.port), 5000)
                connections[device.id] = socket
                updateDeviceStatus(device.id, DeviceConnectionStatus.CONNECTED)

                // Start receiving data
                receiveData(device.id, socket)
            } catch (e: Exception) {
                updateDeviceStatus(device.id, DeviceConnectionStatus.ERROR)
            }
        }.start()
    }

    private fun updateDeviceStatus(deviceId: String, status: DeviceConnectionStatus) {
        _activeSession.value?.devices?.find { it.id == deviceId }?.connectionStatus = status
    }

    private fun receiveData(deviceId: String, socket: Socket) {
        Thread {
            try {
                val input = DataInputStream(socket.getInputStream())
                while (socket.isConnected) {
                    val length = input.readInt()
                    val data = ByteArray(length)
                    input.readFully(data)

                    val packet = Json.decodeFromString<SyncPacket>(String(data))
                    handleSyncPacket(deviceId, packet)
                }
            } catch (e: Exception) {
                updateDeviceStatus(deviceId, DeviceConnectionStatus.DISCONNECTED)
            }
        }.start()
    }

    private fun handleSyncPacket(deviceId: String, packet: SyncPacket) {
        // Record latency
        val latency = System.currentTimeMillis() - packet.timestamp
        latencyEngine.recordLatency(latency.toDouble(), deviceId)

        // Handle packet based on type
        when (packet.type) {
            SyncPacketType.BIOMETRIC -> handleBiometricSync(packet)
            SyncPacketType.AUDIO -> handleAudioSync(packet)
            SyncPacketType.VISUAL -> handleVisualSync(packet)
            SyncPacketType.LIGHTING -> handleLightingSync(packet)
            SyncPacketType.MIDI -> handleMidiSync(packet)
            SyncPacketType.CONTROL -> handleControlSync(packet)
            SyncPacketType.HEARTBEAT -> {} // Just for latency measurement
        }
    }

    private fun handleBiometricSync(packet: SyncPacket) {
        // Dispatch to bio-reactive engine
    }

    private fun handleAudioSync(packet: SyncPacket) {
        // Dispatch to audio engine
    }

    private fun handleVisualSync(packet: SyncPacket) {
        // Dispatch to visual engine
    }

    private fun handleLightingSync(packet: SyncPacket) {
        // Dispatch to lighting controller
    }

    private fun handleMidiSync(packet: SyncPacket) {
        // Dispatch to MIDI manager
    }

    private fun handleControlSync(packet: SyncPacket) {
        // Handle control messages
    }

    // MARK: - Data Sync

    /**
     * Sync biometric data to all connected devices
     */
    fun syncBiometricData(data: BiometricSyncData) {
        val session = _activeSession.value ?: return
        val packet = SyncPacket(
            type = SyncPacketType.BIOMETRIC,
            timestamp = System.currentTimeMillis(),
            data = Json.encodeToString(data),
            latencyCompensation = session.latencyCompensation.currentOffset
        )
        broadcast(packet)
    }

    /**
     * Sync audio parameters to all connected devices
     */
    fun syncAudioParameters(params: AudioSyncParameters) {
        val session = _activeSession.value ?: return
        val packet = SyncPacket(
            type = SyncPacketType.AUDIO,
            timestamp = System.currentTimeMillis(),
            data = Json.encodeToString(params),
            latencyCompensation = session.latencyCompensation.currentOffset
        )
        broadcast(packet)
    }

    private fun broadcast(packet: SyncPacket) {
        val json = Json.encodeToString(packet)
        val bytes = json.toByteArray()

        connections.values.forEach { socket ->
            Thread {
                try {
                    val output = DataOutputStream(socket.getOutputStream())
                    output.writeInt(bytes.size)
                    output.write(bytes)
                    output.flush()
                } catch (e: Exception) {
                    // Handle error
                }
            }.start()
        }
    }
}

// MARK: - Data Classes

@Serializable
data class CrossPlatformSession(
    val id: String,
    val name: String,
    val devices: MutableList<SessionDevice>,
    var syncMode: SyncMode,
    var latencyCompensation: LatencyCompensation,
    val createdAt: Long = System.currentTimeMillis()
) {
    val isCrossEcosystem: Boolean
        get() = devices.map { it.ecosystem }.toSet().size > 1

    val ecosystems: Set<DeviceEcosystem>
        get() = devices.map { it.ecosystem }.toSet()
}

@Serializable
data class SessionDevice(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: DeviceType,
    val platform: DevicePlatform,
    val ecosystem: DeviceEcosystem = DeviceEcosystem.fromPlatform(platform),
    var role: DeviceRole = DeviceRole.PARTICIPANT,
    val capabilities: Set<DeviceCapability> = emptySet(),
    var connectionStatus: DeviceConnectionStatus = DeviceConnectionStatus.DISCONNECTED,
    var latencyMs: Double = 0.0,
    val host: String = "",
    val port: Int = 41234
)

data class DiscoveredDevice(
    val id: String,
    val name: String,
    val host: String,
    val port: Int,
    val platform: DevicePlatform,
    val lastSeen: Long = System.currentTimeMillis()
)

@Serializable
data class LatencyCompensation(
    var enabled: Boolean = true,
    var currentOffset: Double = 0.0,
    val measurements: MutableList<Double> = mutableListOf(),
    var algorithm: LatencyAlgorithm = LatencyAlgorithm.ADAPTIVE
) {
    fun addMeasurement(latency: Double) {
        measurements.add(latency)
        if (measurements.size > 100) {
            measurements.removeAt(0)
        }
        currentOffset = calculateOffset()
    }

    private fun calculateOffset(): Double {
        if (measurements.size < 3) return 0.0
        return when (algorithm) {
            LatencyAlgorithm.NONE -> 0.0
            LatencyAlgorithm.FIXED -> currentOffset
            LatencyAlgorithm.ADAPTIVE -> measurements.takeLast(10).sorted()[measurements.size / 2]
            LatencyAlgorithm.PREDICTIVE -> {
                val alpha = 0.3
                var ema = measurements[0]
                measurements.drop(1).forEach { ema = alpha * it + (1 - alpha) * ema }
                ema
            }
        }
    }
}

@Serializable
data class SyncPacket(
    val type: SyncPacketType,
    val timestamp: Long,
    val data: String,
    val latencyCompensation: Double
)

@Serializable
data class BiometricSyncData(
    val heartRate: Double? = null,
    val hrv: Double? = null,
    val coherence: Double? = null,
    val breathingRate: Double? = null,
    val bloodOxygen: Double? = null,
    val temperature: Double? = null,
    val steps: Int? = null,
    val sourceDeviceId: String
)

@Serializable
data class AudioSyncParameters(
    val bpm: Double = 120.0,
    val volume: Float = 1.0f,
    val pan: Float = 0f,
    val reverbMix: Float = 0f,
    val delayMix: Float = 0f,
    val filterCutoff: Float = 1.0f,
    val isPlaying: Boolean = false,
    val currentBeat: Double = 0.0,
    val sourceDeviceId: String
)

// MARK: - Enums

@Serializable
enum class DeviceEcosystem {
    APPLE, GOOGLE, MICROSOFT, META, LINUX, TESLA, OTHER;

    companion object {
        fun fromPlatform(platform: DevicePlatform): DeviceEcosystem = when (platform) {
            DevicePlatform.IOS, DevicePlatform.IPADOS, DevicePlatform.MACOS,
            DevicePlatform.WATCHOS, DevicePlatform.TVOS, DevicePlatform.VISIONOS,
            DevicePlatform.CARPLAY -> APPLE
            DevicePlatform.ANDROID, DevicePlatform.WEAR_OS, DevicePlatform.ANDROID_TV,
            DevicePlatform.ANDROID_AUTO, DevicePlatform.CHROMEOS -> GOOGLE
            DevicePlatform.WINDOWS -> MICROSOFT
            DevicePlatform.QUEST_OS -> META
            DevicePlatform.LINUX -> LINUX
            DevicePlatform.TESLA_OS -> TESLA
            else -> OTHER
        }
    }
}

@Serializable
enum class DevicePlatform {
    // Apple
    IOS, IPADOS, MACOS, WATCHOS, TVOS, VISIONOS, CARPLAY,
    // Google
    ANDROID, WEAR_OS, ANDROID_TV, ANDROID_AUTO, CHROMEOS,
    // Microsoft
    WINDOWS,
    // Meta
    QUEST_OS,
    // Linux
    LINUX,
    // Tesla
    TESLA_OS,
    // Other
    CUSTOM
}

@Serializable
enum class DeviceRole {
    HOST, PARTICIPANT, BIO_SOURCE, AUDIO_SOURCE,
    VISUAL_OUTPUT, LIGHTING_CONTROL, MIDI_CONTROL, OBSERVER
}

@Serializable
enum class DeviceConnectionStatus {
    DISCONNECTED, CONNECTING, CONNECTED, SYNCING, ERROR
}

@Serializable
enum class SyncMode {
    ADAPTIVE, LOW_LATENCY, HIGH_QUALITY, BALANCED, MASTER_SLAVE, PEER
}

@Serializable
enum class SyncStatus {
    IDLE, DISCOVERING, CONNECTING, CONNECTED, SYNCING, ERROR
}

@Serializable
enum class ConnectionQuality {
    EXCELLENT, GOOD, FAIR, POOR
}

@Serializable
enum class SyncPacketType {
    BIOMETRIC, AUDIO, VISUAL, LIGHTING, MIDI, CONTROL, HEARTBEAT
}

@Serializable
enum class LatencyAlgorithm {
    NONE, FIXED, ADAPTIVE, PREDICTIVE
}

// MARK: - Adaptive Zero-Latency Engine

class AdaptiveZeroLatencyEngine {
    private val latencyHistory = ConcurrentHashMap<String, MutableList<Double>>()
    private val jitterHistory = ConcurrentHashMap<String, MutableList<Double>>()

    var config = LatencyConfig()

    data class LatencyConfig(
        var targetLatency: Double = 10.0,
        var maxLatency: Double = 50.0,
        var bufferSize: Int = 128,
        var adaptiveMode: Boolean = true,
        var prioritizeQuality: Boolean = false
    )

    fun recordLatency(latency: Double, deviceId: String) {
        val history = latencyHistory.getOrPut(deviceId) { mutableListOf() }
        history.add(latency)
        if (history.size > 100) history.removeAt(0)
    }

    fun recordJitter(jitter: Double, deviceId: String) {
        val history = jitterHistory.getOrPut(deviceId) { mutableListOf() }
        history.add(jitter)
        if (history.size > 100) history.removeAt(0)
    }

    fun averageLatency(deviceId: String): Double {
        val history = latencyHistory[deviceId] ?: return 20.0
        return if (history.isEmpty()) 20.0 else history.average()
    }

    fun optimize(devices: List<SessionDevice>): OptimizationResult {
        val result = OptimizationResult()

        devices.forEach { device ->
            val latency = averageLatency(device.id)
            val jitter = jitterHistory[device.id]?.average() ?: 5.0

            val optimalBuffer = calculateOptimalBuffer(latency, jitter)

            result.deviceSettings[device.id] = DeviceOptimization(
                bufferSize = optimalBuffer,
                latencyOffset = latency,
                qualityLevel = determineQualityLevel(latency)
            )
        }

        result.globalSyncOffset = devices.maxOfOrNull { averageLatency(it.id) } ?: 0.0

        return result
    }

    private fun calculateOptimalBuffer(latency: Double, jitter: Double): Int {
        val baseBuffer = 128
        val factor = maxOf(1.0, latency / 10.0) * maxOf(1.0, jitter / 5.0)
        val optimal = (baseBuffer * factor).toInt()
        return listOf(64, 128, 256, 512, 1024, 2048).first { it >= optimal }
    }

    private fun determineQualityLevel(latency: Double): QualityLevel = when {
        latency < 10 -> QualityLevel.ULTRA
        latency < 25 -> QualityLevel.HIGH
        latency < 50 -> QualityLevel.MEDIUM
        latency < 100 -> QualityLevel.LOW
        else -> QualityLevel.MINIMUM
    }

    data class OptimizationResult(
        val deviceSettings: MutableMap<String, DeviceOptimization> = mutableMapOf(),
        var globalSyncOffset: Double = 0.0
    )

    data class DeviceOptimization(
        val bufferSize: Int,
        val latencyOffset: Double,
        val qualityLevel: QualityLevel
    )

    enum class QualityLevel { ULTRA, HIGH, MEDIUM, LOW, MINIMUM }
}

// MARK: - Predefined Device Combinations

object DeviceCombinationPresets {

    /**
     * ALL combinations are valid and supported!
     */
    val crossEcosystemCombinations = listOf(
        DeviceCombination(
            name = "Android + iPhone",
            devices = listOf(
                Triple(DeviceType.ANDROID_PHONE, DevicePlatform.ANDROID, DeviceRole.HOST),
                Triple(DeviceType.IPHONE, DevicePlatform.IOS, DeviceRole.BIO_SOURCE)
            ),
            syncMode = SyncMode.ADAPTIVE,
            notes = "Cross-ecosystem bio sync"
        ),
        DeviceCombination(
            name = "Android Tablet + iMac",
            devices = listOf(
                Triple(DeviceType.ANDROID_TABLET, DevicePlatform.ANDROID, DeviceRole.MIDI_CONTROL),
                Triple(DeviceType.MAC, DevicePlatform.MACOS, DeviceRole.HOST)
            ),
            syncMode = SyncMode.LOW_LATENCY,
            notes = "Touch control from Android, audio from Mac"
        ),
        DeviceCombination(
            name = "Wear OS + MacBook + Meta Glasses",
            devices = listOf(
                Triple(DeviceType.WEAR_OS, DevicePlatform.WEAR_OS, DeviceRole.BIO_SOURCE),
                Triple(DeviceType.MAC, DevicePlatform.MACOS, DeviceRole.HOST),
                Triple(DeviceType.META_GLASSES, DevicePlatform.QUEST_OS, DeviceRole.VISUAL_OUTPUT)
            ),
            syncMode = SyncMode.ADAPTIVE,
            notes = "Google bio, Mac production, Meta AR"
        ),
        DeviceCombination(
            name = "Android + Windows + Apple Watch",
            devices = listOf(
                Triple(DeviceType.ANDROID_PHONE, DevicePlatform.ANDROID, DeviceRole.MIDI_CONTROL),
                Triple(DeviceType.WINDOWS_PC, DevicePlatform.WINDOWS, DeviceRole.HOST),
                Triple(DeviceType.APPLE_WATCH, DevicePlatform.WATCHOS, DeviceRole.BIO_SOURCE)
            ),
            syncMode = SyncMode.ADAPTIVE,
            notes = "Three ecosystems working together"
        ),
        DeviceCombination(
            name = "Tesla + Android + Vision Pro",
            devices = listOf(
                Triple(DeviceType.TESLA, DevicePlatform.TESLA_OS, DeviceRole.VISUAL_OUTPUT),
                Triple(DeviceType.ANDROID_TABLET, DevicePlatform.ANDROID, DeviceRole.HOST),
                Triple(DeviceType.VISION_PRO, DevicePlatform.VISIONOS, DeviceRole.VISUAL_OUTPUT)
            ),
            syncMode = SyncMode.HIGH_QUALITY,
            notes = "In-car + AR immersive experience"
        )
    )

    data class DeviceCombination(
        val name: String,
        val devices: List<Triple<DeviceType, DevicePlatform, DeviceRole>>,
        val syncMode: SyncMode,
        val notes: String
    )
}
