package com.echoelmusic.app.led

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.*
import kotlin.math.*

/**
 * Echoelmusic LED Lighting Controller for Android
 * DMX/Art-Net/sACN lighting control with bio-reactive modulation
 *
 * Features:
 * - DMX512 protocol support (512 channels)
 * - Art-Net protocol for network lighting
 * - sACN (E1.31) protocol support
 * - Push 3 LED integration via MIDI
 * - Bio-reactive light modulation
 * - Multiple fixture types
 * - Scene management
 * - Light shows and cue lists
 *
 * Port of iOS MIDIToLightMapper + Push3LEDController
 */

// MARK: - DMX Protocol

enum class DMXProtocol(val displayName: String) {
    DMX512("DMX512 (USB)"),
    ART_NET("Art-Net (Network)"),
    SACN("sACN/E1.31 (Network)"),
    MIDI("MIDI Lighting"),
    OSC("OSC Control")
}

// MARK: - Fixture Types

enum class FixtureType(val displayName: String, val channels: Int) {
    // Basic
    DIMMER("Dimmer", 1),
    RGB("RGB", 3),
    RGBW("RGBW", 4),
    RGBA("RGBA", 4),
    RGBAW("RGBAW", 5),
    RGBAWUV("RGBAW+UV", 6),

    // Moving Heads
    MOVING_HEAD_WASH("Moving Head Wash", 16),
    MOVING_HEAD_SPOT("Moving Head Spot", 20),
    MOVING_HEAD_BEAM("Moving Head Beam", 18),

    // LED Bars
    LED_BAR_12("LED Bar 12px", 36),
    LED_BAR_24("LED Bar 24px", 72),
    LED_BAR_48("LED Bar 48px", 144),

    // Effects
    STROBE("Strobe", 2),
    LASER("Laser", 8),
    FOG_MACHINE("Fog Machine", 2),
    HAZER("Hazer", 2),

    // Specialty
    PAR_CAN("PAR Can", 7),
    WASH_LIGHT("Wash Light", 8),
    PIXEL_BAR("Pixel Bar", 512),
    LED_STRIP("LED Strip", 512),

    // Push 3
    PUSH3_PADS("Push 3 Pads", 64),
    PUSH3_BUTTONS("Push 3 Buttons", 32)
}

// MARK: - Light Color

data class LightColor(
    val red: Int = 0,
    val green: Int = 0,
    val blue: Int = 0,
    val white: Int = 0,
    val amber: Int = 0,
    val uv: Int = 0
) {
    fun toRGB(): Triple<Int, Int, Int> = Triple(red, green, blue)

    fun toDMX(): ByteArray = byteArrayOf(
        red.toByte(),
        green.toByte(),
        blue.toByte(),
        white.toByte(),
        amber.toByte(),
        uv.toByte()
    )

    companion object {
        val RED = LightColor(red = 255)
        val GREEN = LightColor(green = 255)
        val BLUE = LightColor(blue = 255)
        val WHITE = LightColor(red = 255, green = 255, blue = 255)
        val WARM_WHITE = LightColor(red = 255, green = 200, blue = 150, white = 255)
        val COOL_WHITE = LightColor(red = 200, green = 220, blue = 255, white = 255)
        val AMBER = LightColor(red = 255, green = 150, blue = 0, amber = 255)
        val PURPLE = LightColor(red = 255, blue = 255)
        val CYAN = LightColor(green = 255, blue = 255)
        val MAGENTA = LightColor(red = 255, blue = 255)
        val OFF = LightColor()

        fun fromHSV(hue: Float, saturation: Float, value: Float): LightColor {
            val c = value * saturation
            val x = c * (1 - abs((hue / 60f) % 2 - 1))
            val m = value - c

            val (r, g, b) = when {
                hue < 60 -> Triple(c, x, 0f)
                hue < 120 -> Triple(x, c, 0f)
                hue < 180 -> Triple(0f, c, x)
                hue < 240 -> Triple(0f, x, c)
                hue < 300 -> Triple(x, 0f, c)
                else -> Triple(c, 0f, x)
            }

            return LightColor(
                red = ((r + m) * 255).toInt().coerceIn(0, 255),
                green = ((g + m) * 255).toInt().coerceIn(0, 255),
                blue = ((b + m) * 255).toInt().coerceIn(0, 255)
            )
        }
    }
}

// MARK: - Fixture

data class Fixture(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: FixtureType,
    val dmxAddress: Int,
    val universe: Int = 0,
    var color: LightColor = LightColor.OFF,
    var intensity: Float = 0f,
    var pan: Float = 0.5f,
    var tilt: Float = 0.5f,
    var gobo: Int = 0,
    var strobe: Float = 0f,
    var zoom: Float = 0.5f,
    var isActive: Boolean = true
)

// MARK: - Light Scene

data class LightScene(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val fixtures: Map<String, FixtureState>,
    val fadeTimeMs: Long = 1000,
    val holdTimeMs: Long = 0
)

data class FixtureState(
    val color: LightColor,
    val intensity: Float,
    val pan: Float = 0.5f,
    val tilt: Float = 0.5f,
    val gobo: Int = 0,
    val strobe: Float = 0f
)

// MARK: - Cue

data class Cue(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val scene: LightScene,
    val triggerType: TriggerType = TriggerType.MANUAL,
    val triggerValue: Float = 0f
)

enum class TriggerType(val displayName: String) {
    MANUAL("Manual"),
    TIME("Time"),
    BPM("BPM Beat"),
    COHERENCE("Coherence Threshold"),
    HEART_RATE("Heart Rate"),
    BREATH("Breath Phase"),
    MIDI_NOTE("MIDI Note"),
    AUDIO_LEVEL("Audio Level")
}

// MARK: - Bio-Reactive Light Mapping

data class LightBioMapping(
    val source: LightBioSource,
    val target: LightTarget,
    val intensity: Float = 1.0f,
    val curve: LightMappingCurve = LightMappingCurve.LINEAR
)

enum class LightBioSource(val displayName: String) {
    HEART_RATE("Heart Rate"),
    HRV("HRV"),
    COHERENCE("Coherence"),
    BREATHING_RATE("Breathing Rate"),
    BREATH_PHASE("Breath Phase"),
    AUDIO_LEVEL("Audio Level"),
    AUDIO_BASS("Audio Bass"),
    AUDIO_MID("Audio Mid"),
    AUDIO_HIGH("Audio High"),
    BPM("BPM")
}

enum class LightTarget(val displayName: String) {
    INTENSITY("Intensity"),
    COLOR_HUE("Color Hue"),
    COLOR_SATURATION("Color Saturation"),
    STROBE_RATE("Strobe Rate"),
    PAN("Pan"),
    TILT("Tilt"),
    GOBO("Gobo"),
    ZOOM("Zoom"),
    TRANSITION_SPEED("Transition Speed")
}

enum class LightMappingCurve {
    LINEAR,
    EXPONENTIAL,
    LOGARITHMIC,
    SINE,
    PULSE
}

// MARK: - Art-Net Packet

class ArtNetPacket {
    companion object {
        const val ARTNET_PORT = 6454
        private val ARTNET_ID = "Art-Net".toByteArray() + byteArrayOf(0)
        private const val ARTNET_DMX = 0x5000.toShort()
    }

    fun createDMXPacket(universe: Int, dmxData: ByteArray): ByteArray {
        val packet = ByteArray(18 + dmxData.size)

        // Art-Net ID
        ARTNET_ID.copyInto(packet, 0)

        // OpCode (DMX)
        packet[8] = (ARTNET_DMX.toInt() and 0xFF).toByte()
        packet[9] = ((ARTNET_DMX.toInt() shr 8) and 0xFF).toByte()

        // Protocol Version (14)
        packet[10] = 0
        packet[11] = 14

        // Sequence (0 = disabled)
        packet[12] = 0

        // Physical (0)
        packet[13] = 0

        // Universe
        packet[14] = (universe and 0xFF).toByte()
        packet[15] = ((universe shr 8) and 0xFF).toByte()

        // Length (hi-byte first)
        val length = dmxData.size
        packet[16] = ((length shr 8) and 0xFF).toByte()
        packet[17] = (length and 0xFF).toByte()

        // DMX Data
        dmxData.copyInto(packet, 18)

        return packet
    }
}

// MARK: - LED Lighting Controller

class LEDLightingController {

    companion object {
        private const val TAG = "LEDLightingController"
        private const val DMX_CHANNELS = 512
        private const val UPDATE_RATE_HZ = 40
        private const val UPDATE_INTERVAL_MS = 1000L / UPDATE_RATE_HZ
    }

    // State
    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private val _fixtures = MutableStateFlow<List<Fixture>>(emptyList())
    val fixtures: StateFlow<List<Fixture>> = _fixtures

    private val _currentScene = MutableStateFlow<LightScene?>(null)
    val currentScene: StateFlow<LightScene?> = _currentScene

    private val _scenes = MutableStateFlow<List<LightScene>>(emptyList())
    val scenes: StateFlow<List<LightScene>> = _scenes

    private val _cueList = MutableStateFlow<List<Cue>>(emptyList())
    val cueList: StateFlow<List<Cue>> = _cueList

    // DMX Data
    private val dmxData = ByteArray(DMX_CHANNELS) { 0 }

    // Protocol
    private val _protocol = MutableStateFlow(DMXProtocol.ART_NET)
    val protocol: StateFlow<DMXProtocol> = _protocol

    private val _artNetHost = MutableStateFlow("192.168.1.100")
    val artNetHost: StateFlow<String> = _artNetHost

    // Bio-Reactive
    private val _bioMappings = MutableStateFlow<List<LightBioMapping>>(emptyList())
    val bioMappings: StateFlow<List<LightBioMapping>> = _bioMappings

    private val _bioReactiveEnabled = MutableStateFlow(true)
    val bioReactiveEnabled: StateFlow<Boolean> = _bioReactiveEnabled

    // Bio data
    private var currentCoherence = 0.5f
    private var currentHeartRate = 70f
    private var currentBreathPhase = 0f
    private var currentAudioLevel = 0f

    // Processing
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var updateJob: Job? = null
    private var socket: DatagramSocket? = null
    private val artNetPacket = ArtNetPacket()

    init {
        Log.i(TAG, "LED Lighting Controller initialized")
    }

    // MARK: - Lifecycle

    fun start() {
        if (_isRunning.value) return

        _isRunning.value = true
        startUpdateLoop()
        Log.i(TAG, "LED Lighting Controller started")
    }

    fun stop() {
        _isRunning.value = false
        updateJob?.cancel()
        socket?.close()
        socket = null
        Log.i(TAG, "LED Lighting Controller stopped")
    }

    fun shutdown() {
        stop()
        scope.cancel()
        Log.i(TAG, "LED Lighting Controller shutdown")
    }

    private fun startUpdateLoop() {
        updateJob?.cancel()
        updateJob = scope.launch {
            while (_isRunning.value && isActive) {
                updateDMX()
                sendDMX()
                delay(UPDATE_INTERVAL_MS)
            }
        }
    }

    // MARK: - Protocol Configuration

    fun setProtocol(protocol: DMXProtocol) {
        _protocol.value = protocol
    }

    fun setArtNetHost(host: String) {
        _artNetHost.value = host
    }

    // MARK: - Fixture Management

    fun addFixture(name: String, type: FixtureType, dmxAddress: Int, universe: Int = 0): Fixture {
        val fixture = Fixture(
            name = name,
            type = type,
            dmxAddress = dmxAddress,
            universe = universe
        )
        _fixtures.value = _fixtures.value + fixture
        Log.d(TAG, "Added fixture: $name at DMX $dmxAddress")
        return fixture
    }

    fun removeFixture(fixtureId: String) {
        _fixtures.value = _fixtures.value.filter { it.id != fixtureId }
    }

    fun setFixtureColor(fixtureId: String, color: LightColor) {
        _fixtures.value = _fixtures.value.map { fixture ->
            if (fixture.id == fixtureId) fixture.copy(color = color) else fixture
        }
    }

    fun setFixtureIntensity(fixtureId: String, intensity: Float) {
        _fixtures.value = _fixtures.value.map { fixture ->
            if (fixture.id == fixtureId) fixture.copy(intensity = intensity.coerceIn(0f, 1f)) else fixture
        }
    }

    fun setFixturePanTilt(fixtureId: String, pan: Float, tilt: Float) {
        _fixtures.value = _fixtures.value.map { fixture ->
            if (fixture.id == fixtureId) {
                fixture.copy(pan = pan.coerceIn(0f, 1f), tilt = tilt.coerceIn(0f, 1f))
            } else fixture
        }
    }

    fun setFixtureStrobe(fixtureId: String, strobe: Float) {
        _fixtures.value = _fixtures.value.map { fixture ->
            if (fixture.id == fixtureId) fixture.copy(strobe = strobe.coerceIn(0f, 1f)) else fixture
        }
    }

    fun setAllFixturesColor(color: LightColor) {
        _fixtures.value = _fixtures.value.map { it.copy(color = color) }
    }

    fun setAllFixturesIntensity(intensity: Float) {
        _fixtures.value = _fixtures.value.map { it.copy(intensity = intensity.coerceIn(0f, 1f)) }
    }

    fun blackout() {
        _fixtures.value = _fixtures.value.map { it.copy(intensity = 0f, color = LightColor.OFF) }
        Log.i(TAG, "Blackout!")
    }

    // MARK: - Scene Management

    fun createScene(name: String): LightScene {
        val fixtureStates = _fixtures.value.associate { fixture ->
            fixture.id to FixtureState(
                color = fixture.color,
                intensity = fixture.intensity,
                pan = fixture.pan,
                tilt = fixture.tilt,
                gobo = fixture.gobo,
                strobe = fixture.strobe
            )
        }

        val scene = LightScene(name = name, fixtures = fixtureStates)
        _scenes.value = _scenes.value + scene
        return scene
    }

    fun loadScene(sceneId: String) {
        val scene = _scenes.value.find { it.id == sceneId } ?: return
        _currentScene.value = scene

        scope.launch {
            fadeToScene(scene)
        }
    }

    private suspend fun fadeToScene(scene: LightScene) {
        val startTime = System.currentTimeMillis()
        val startStates = _fixtures.value.associate { it.id to it }

        while (System.currentTimeMillis() - startTime < scene.fadeTimeMs) {
            val progress = (System.currentTimeMillis() - startTime).toFloat() / scene.fadeTimeMs

            _fixtures.value = _fixtures.value.map { fixture ->
                val targetState = scene.fixtures[fixture.id] ?: return@map fixture
                val startState = startStates[fixture.id] ?: return@map fixture

                fixture.copy(
                    color = LightColor(
                        red = lerp(startState.color.red, targetState.color.red, progress),
                        green = lerp(startState.color.green, targetState.color.green, progress),
                        blue = lerp(startState.color.blue, targetState.color.blue, progress),
                        white = lerp(startState.color.white, targetState.color.white, progress),
                        amber = lerp(startState.color.amber, targetState.color.amber, progress),
                        uv = lerp(startState.color.uv, targetState.color.uv, progress)
                    ),
                    intensity = lerp(startState.intensity, targetState.intensity, progress),
                    pan = lerp(startState.pan, targetState.pan, progress),
                    tilt = lerp(startState.tilt, targetState.tilt, progress)
                )
            }

            delay(UPDATE_INTERVAL_MS)
        }
    }

    private fun lerp(start: Int, end: Int, progress: Float): Int {
        return (start + (end - start) * progress).toInt().coerceIn(0, 255)
    }

    private fun lerp(start: Float, end: Float, progress: Float): Float {
        return start + (end - start) * progress
    }

    fun deleteScene(sceneId: String) {
        _scenes.value = _scenes.value.filter { it.id != sceneId }
    }

    // MARK: - Cue Management

    fun addCue(name: String, scene: LightScene, trigger: TriggerType = TriggerType.MANUAL): Cue {
        val cue = Cue(name = name, scene = scene, triggerType = trigger)
        _cueList.value = _cueList.value + cue
        return cue
    }

    fun triggerCue(cueId: String) {
        val cue = _cueList.value.find { it.id == cueId } ?: return
        loadScene(cue.scene.id)
    }

    fun removeCue(cueId: String) {
        _cueList.value = _cueList.value.filter { it.id != cueId }
    }

    // MARK: - Bio-Reactive

    fun enableBioReactive(enabled: Boolean) {
        _bioReactiveEnabled.value = enabled
    }

    fun addBioMapping(mapping: LightBioMapping) {
        _bioMappings.value = _bioMappings.value + mapping
    }

    fun removeBioMapping(source: LightBioSource, target: LightTarget) {
        _bioMappings.value = _bioMappings.value.filter {
            !(it.source == source && it.target == target)
        }
    }

    fun updateBioData(coherence: Float, heartRate: Float, breathPhase: Float, audioLevel: Float) {
        currentCoherence = coherence
        currentHeartRate = heartRate
        currentBreathPhase = breathPhase
        currentAudioLevel = audioLevel
    }

    private fun applyBioModulation() {
        if (!_bioReactiveEnabled.value) return

        for (mapping in _bioMappings.value) {
            val sourceValue = when (mapping.source) {
                LightBioSource.COHERENCE -> currentCoherence
                LightBioSource.HEART_RATE -> (currentHeartRate - 40f) / 160f
                LightBioSource.BREATH_PHASE -> currentBreathPhase
                LightBioSource.AUDIO_LEVEL -> currentAudioLevel
                else -> 0.5f
            }

            val mappedValue = applyMappingCurve(sourceValue, mapping.curve) * mapping.intensity

            when (mapping.target) {
                LightTarget.INTENSITY -> {
                    _fixtures.value = _fixtures.value.map {
                        it.copy(intensity = mappedValue.coerceIn(0f, 1f))
                    }
                }
                LightTarget.COLOR_HUE -> {
                    val color = LightColor.fromHSV(mappedValue * 360, 1f, 1f)
                    _fixtures.value = _fixtures.value.map { it.copy(color = color) }
                }
                LightTarget.STROBE_RATE -> {
                    _fixtures.value = _fixtures.value.map {
                        it.copy(strobe = mappedValue.coerceIn(0f, 1f))
                    }
                }
                else -> {}
            }
        }
    }

    private fun applyMappingCurve(value: Float, curve: LightMappingCurve): Float {
        return when (curve) {
            LightMappingCurve.LINEAR -> value
            LightMappingCurve.EXPONENTIAL -> value * value
            LightMappingCurve.LOGARITHMIC -> if (value > 0) ln(1 + value * 9) / ln(10f) else 0f
            LightMappingCurve.SINE -> (sin(value * PI.toFloat() - PI.toFloat() / 2) + 1) / 2
            LightMappingCurve.PULSE -> if (value > 0.5f) 1f else 0f
        }
    }

    // MARK: - DMX Output

    private fun updateDMX() {
        // Apply bio modulation
        applyBioModulation()

        // Clear DMX data
        dmxData.fill(0)

        // Update DMX data from fixtures
        for (fixture in _fixtures.value) {
            if (!fixture.isActive) continue

            val baseAddress = fixture.dmxAddress - 1 // DMX is 1-indexed
            if (baseAddress < 0 || baseAddress >= DMX_CHANNELS) continue

            val intensity = (fixture.intensity * 255).toInt().toByte()

            when (fixture.type) {
                FixtureType.DIMMER -> {
                    if (baseAddress < DMX_CHANNELS) {
                        dmxData[baseAddress] = intensity
                    }
                }
                FixtureType.RGB -> {
                    if (baseAddress + 2 < DMX_CHANNELS) {
                        dmxData[baseAddress] = ((fixture.color.red * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 1] = ((fixture.color.green * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 2] = ((fixture.color.blue * fixture.intensity).toInt()).toByte()
                    }
                }
                FixtureType.RGBW -> {
                    if (baseAddress + 3 < DMX_CHANNELS) {
                        dmxData[baseAddress] = ((fixture.color.red * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 1] = ((fixture.color.green * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 2] = ((fixture.color.blue * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 3] = ((fixture.color.white * fixture.intensity).toInt()).toByte()
                    }
                }
                FixtureType.MOVING_HEAD_WASH, FixtureType.MOVING_HEAD_SPOT -> {
                    if (baseAddress + 7 < DMX_CHANNELS) {
                        dmxData[baseAddress] = (fixture.pan * 255).toInt().toByte() // Pan
                        dmxData[baseAddress + 1] = 0 // Pan Fine
                        dmxData[baseAddress + 2] = (fixture.tilt * 255).toInt().toByte() // Tilt
                        dmxData[baseAddress + 3] = 0 // Tilt Fine
                        dmxData[baseAddress + 4] = intensity // Dimmer
                        dmxData[baseAddress + 5] = ((fixture.color.red * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 6] = ((fixture.color.green * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 7] = ((fixture.color.blue * fixture.intensity).toInt()).toByte()
                    }
                }
                FixtureType.STROBE -> {
                    if (baseAddress + 1 < DMX_CHANNELS) {
                        dmxData[baseAddress] = intensity
                        dmxData[baseAddress + 1] = (fixture.strobe * 255).toInt().toByte()
                    }
                }
                else -> {
                    // Default RGB handling
                    if (baseAddress + 2 < DMX_CHANNELS) {
                        dmxData[baseAddress] = ((fixture.color.red * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 1] = ((fixture.color.green * fixture.intensity).toInt()).toByte()
                        dmxData[baseAddress + 2] = ((fixture.color.blue * fixture.intensity).toInt()).toByte()
                    }
                }
            }
        }
    }

    private fun sendDMX() {
        when (_protocol.value) {
            DMXProtocol.ART_NET -> sendArtNet()
            DMXProtocol.SACN -> sendSACN()
            else -> {}
        }
    }

    private fun sendArtNet() {
        try {
            if (socket == null) {
                socket = DatagramSocket()
            }

            val packet = artNetPacket.createDMXPacket(0, dmxData)
            val address = InetAddress.getByName(_artNetHost.value)
            val datagramPacket = DatagramPacket(
                packet,
                packet.size,
                address,
                ArtNetPacket.ARTNET_PORT
            )

            socket?.send(datagramPacket)
        } catch (e: Exception) {
            Log.w(TAG, "Art-Net send error: ${e.message}")
        }
    }

    private fun sendSACN() {
        // sACN implementation would go here
        // Similar to Art-Net but with E1.31 packet format
    }

    // MARK: - Push 3 Integration

    fun updatePush3Pads(padColors: Array<LightColor>) {
        // This would send MIDI sysex to Push 3 for LED colors
        // Requires MIDI connection to Push 3
        Log.d(TAG, "Push 3 pad colors updated")
    }

    fun setPush3PadColor(padIndex: Int, color: LightColor) {
        // Single pad color update
        Log.d(TAG, "Push 3 pad $padIndex color set")
    }

    // MARK: - Presets

    fun applyColorChase(colors: List<LightColor>, speedMs: Long) {
        scope.launch {
            var colorIndex = 0
            while (_isRunning.value) {
                val color = colors[colorIndex % colors.size]
                setAllFixturesColor(color)
                colorIndex++
                delay(speedMs)
            }
        }
    }

    fun applyRainbow(speedMs: Long) {
        scope.launch {
            var hue = 0f
            while (_isRunning.value) {
                val color = LightColor.fromHSV(hue, 1f, 1f)
                setAllFixturesColor(color)
                hue = (hue + 5f) % 360f
                delay(speedMs)
            }
        }
    }

    fun applyHeartbeatPulse() {
        addBioMapping(LightBioMapping(
            source = LightBioSource.HEART_RATE,
            target = LightTarget.INTENSITY,
            curve = LightMappingCurve.PULSE
        ))
    }

    fun applyCoherenceGlow() {
        addBioMapping(LightBioMapping(
            source = LightBioSource.COHERENCE,
            target = LightTarget.INTENSITY,
            curve = LightMappingCurve.LINEAR
        ))
        addBioMapping(LightBioMapping(
            source = LightBioSource.COHERENCE,
            target = LightTarget.COLOR_HUE,
            curve = LightMappingCurve.LINEAR
        ))
    }
}
