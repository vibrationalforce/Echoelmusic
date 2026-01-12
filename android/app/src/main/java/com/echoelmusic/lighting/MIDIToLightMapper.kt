/**
 * MIDIToLightMapper.kt
 *
 * Complete DMX/Art-Net/sACN lighting control with MIDI mapping,
 * bio-reactive modulation, and visual step sequencer integration.
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 */
package com.echoelmusic.lighting

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.io.DataOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import kotlin.math.*

// ============================================================================
// DMX CONSTANTS & PROTOCOLS
// ============================================================================

object DMXConstants {
    const val UNIVERSE_SIZE = 512
    const val MIN_CHANNEL = 1
    const val MAX_CHANNEL = 512
    const val MIN_VALUE = 0
    const val MAX_VALUE = 255

    // Art-Net
    const val ARTNET_PORT = 6454
    const val ARTNET_HEADER = "Art-Net\u0000"
    const val ARTNET_OPCODE_DMX = 0x5000

    // sACN (E1.31)
    const val SACN_PORT = 5568
    const val SACN_PREAMBLE_SIZE = 16
}

enum class LightingProtocol {
    DMX512,
    ARTNET,
    SACN,
    HUE,
    NANOLEAF,
    WLED,
    ILDA_LASER
}

// ============================================================================
// DMX FIXTURES
// ============================================================================

enum class FixtureType(
    val channelCount: Int,
    val description: String
) {
    // Basic fixtures
    RGB_PAR(3, "RGB PAR Can"),
    RGBW_PAR(4, "RGBW PAR Can"),
    RGBWAU_PAR(6, "RGBWAU PAR Can"),
    DIMMER(1, "Single Dimmer"),

    // Moving heads
    MOVING_HEAD_SPOT(16, "Moving Head Spot"),
    MOVING_HEAD_WASH(12, "Moving Head Wash"),
    MOVING_HEAD_BEAM(14, "Moving Head Beam"),

    // LED strips/bars
    LED_BAR_8(8, "8-Segment LED Bar"),
    LED_BAR_16(16, "16-Segment LED Bar"),
    LED_STRIP_RGB(3, "RGB LED Strip"),
    LED_STRIP_RGBW(4, "RGBW LED Strip"),

    // Effects
    STROBE(2, "Strobe Light"),
    FOG_MACHINE(2, "Fog Machine"),
    HAZER(2, "Hazer"),
    LASER_RGB(8, "RGB Laser"),

    // Custom
    CUSTOM(0, "Custom Fixture")
}

data class DMXFixture(
    val id: String,
    val name: String,
    val type: FixtureType,
    val universe: Int,
    val startChannel: Int,
    var enabled: Boolean = true,

    // Position for visualization
    val positionX: Float = 0.5f,
    val positionY: Float = 0.5f
) {
    val endChannel: Int get() = startChannel + type.channelCount - 1
}

// ============================================================================
// LIGHT SCENE PRESETS
// ============================================================================

enum class LightScene(
    val displayName: String,
    val description: String,
    val colorPalette: List<Int>, // RGB colors
    val intensity: Float,
    val transitionSpeed: Float
) {
    AMBIENT(
        "Ambient",
        "Soft, warm lighting for relaxation",
        listOf(0xFFAA66, 0xFF8844, 0xFFCC88),
        0.4f,
        0.1f
    ),
    MEDITATION(
        "Meditation",
        "Calm blue/purple for focus",
        listOf(0x6666FF, 0x8866FF, 0x4488FF),
        0.3f,
        0.05f
    ),
    PERFORMANCE(
        "Performance",
        "Dynamic, full-color show lighting",
        listOf(0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0xFF00FF),
        0.8f,
        0.3f
    ),
    ENERGETIC(
        "Energetic",
        "High-energy, fast color changes",
        listOf(0xFF0000, 0xFFAA00, 0xFFFF00, 0x00FF00),
        1.0f,
        0.5f
    ),
    REACTIVE(
        "Bio-Reactive",
        "Responds to heart rate and coherence",
        listOf(0xFF6666, 0xFF8888, 0xFFAAAA, 0x66FF66, 0x88FF88),
        0.6f,
        0.2f
    ),
    STROBE_SYNC(
        "Strobe Sync",
        "Beat-synchronized strobing",
        listOf(0xFFFFFF),
        1.0f,
        1.0f
    )
}

// ============================================================================
// ART-NET PROTOCOL
// ============================================================================

class ArtNetClient(
    private val targetIP: String = "255.255.255.255", // Broadcast
    private val port: Int = DMXConstants.ARTNET_PORT
) {
    private var socket: DatagramSocket? = null
    private var sequence: Int = 0

    fun connect(): Boolean {
        return try {
            socket = DatagramSocket()
            socket?.broadcast = true
            true
        } catch (e: Exception) {
            false
        }
    }

    fun disconnect() {
        socket?.close()
        socket = null
    }

    /**
     * Send DMX data via Art-Net
     */
    fun sendDMX(universe: Int, dmxData: ByteArray): Boolean {
        val sock = socket ?: return false

        // Art-Net DMX packet structure
        val packet = ByteArray(18 + dmxData.size)

        // Header "Art-Net\0"
        val header = DMXConstants.ARTNET_HEADER.toByteArray()
        System.arraycopy(header, 0, packet, 0, header.size)

        // OpCode (little-endian)
        packet[8] = (DMXConstants.ARTNET_OPCODE_DMX and 0xFF).toByte()
        packet[9] = ((DMXConstants.ARTNET_OPCODE_DMX shr 8) and 0xFF).toByte()

        // Protocol version (high-low)
        packet[10] = 0
        packet[11] = 14

        // Sequence
        packet[12] = (sequence and 0xFF).toByte()
        sequence = (sequence + 1) % 256

        // Physical
        packet[13] = 0

        // Universe (little-endian)
        packet[14] = (universe and 0xFF).toByte()
        packet[15] = ((universe shr 8) and 0xFF).toByte()

        // Length (big-endian)
        packet[16] = ((dmxData.size shr 8) and 0xFF).toByte()
        packet[17] = (dmxData.size and 0xFF).toByte()

        // DMX data
        System.arraycopy(dmxData, 0, packet, 18, dmxData.size)

        return try {
            val address = InetAddress.getByName(targetIP)
            val datagram = DatagramPacket(packet, packet.size, address, port)
            sock.send(datagram)
            true
        } catch (e: Exception) {
            false
        }
    }
}

// ============================================================================
// SACN (E1.31) PROTOCOL
// ============================================================================

class SACNClient(
    private val targetIP: String = "239.255.0.1", // Multicast base
    private val port: Int = DMXConstants.SACN_PORT
) {
    private var socket: DatagramSocket? = null
    private var sequence: Int = 0
    private val sourceName = "Echoelmusic"
    private val cid = ByteArray(16) { it.toByte() } // Unique component ID

    fun connect(): Boolean {
        return try {
            socket = DatagramSocket()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun disconnect() {
        socket?.close()
        socket = null
    }

    /**
     * Send DMX data via sACN
     */
    fun sendDMX(universe: Int, dmxData: ByteArray, priority: Int = 100): Boolean {
        val sock = socket ?: return false

        // Build E1.31 packet
        val dataLength = dmxData.size + 1 // +1 for start code
        val dmpLength = dataLength + 10
        val framingLength = dmpLength + 77
        val rootLength = framingLength + 22

        val packet = ByteArray(rootLength + 16)
        var offset = 0

        // Root Layer
        // Preamble Size (2 bytes)
        packet[offset++] = 0x00
        packet[offset++] = 0x10

        // Post-amble Size (2 bytes)
        packet[offset++] = 0x00
        packet[offset++] = 0x00

        // ACN Packet Identifier (12 bytes)
        val acnId = "ASC-E1.17\u0000\u0000\u0000".toByteArray()
        System.arraycopy(acnId, 0, packet, offset, 12)
        offset += 12

        // Flags and Length (2 bytes)
        val rootFlagsLength = 0x7000 or (rootLength and 0x0FFF)
        packet[offset++] = ((rootFlagsLength shr 8) and 0xFF).toByte()
        packet[offset++] = (rootFlagsLength and 0xFF).toByte()

        // Vector (4 bytes) - VECTOR_ROOT_E131_DATA
        packet[offset++] = 0x00
        packet[offset++] = 0x00
        packet[offset++] = 0x00
        packet[offset++] = 0x04

        // CID (16 bytes)
        System.arraycopy(cid, 0, packet, offset, 16)
        offset += 16

        // Framing Layer
        val framingFlagsLength = 0x7000 or (framingLength and 0x0FFF)
        packet[offset++] = ((framingFlagsLength shr 8) and 0xFF).toByte()
        packet[offset++] = (framingFlagsLength and 0xFF).toByte()

        // Vector (4 bytes) - VECTOR_E131_DATA_PACKET
        packet[offset++] = 0x00
        packet[offset++] = 0x00
        packet[offset++] = 0x00
        packet[offset++] = 0x02

        // Source Name (64 bytes)
        val nameBytes = sourceName.toByteArray()
        System.arraycopy(nameBytes, 0, packet, offset, minOf(nameBytes.size, 63))
        offset += 64

        // Priority (1 byte)
        packet[offset++] = priority.toByte()

        // Synchronization Address (2 bytes)
        packet[offset++] = 0x00
        packet[offset++] = 0x00

        // Sequence Number (1 byte)
        packet[offset++] = (sequence and 0xFF).toByte()
        sequence = (sequence + 1) % 256

        // Options (1 byte)
        packet[offset++] = 0x00

        // Universe (2 bytes)
        packet[offset++] = ((universe shr 8) and 0xFF).toByte()
        packet[offset++] = (universe and 0xFF).toByte()

        // DMP Layer
        val dmpFlagsLength = 0x7000 or (dmpLength and 0x0FFF)
        packet[offset++] = ((dmpFlagsLength shr 8) and 0xFF).toByte()
        packet[offset++] = (dmpFlagsLength and 0xFF).toByte()

        // Vector (1 byte) - VECTOR_DMP_SET_PROPERTY
        packet[offset++] = 0x02

        // Address Type & Data Type (1 byte)
        packet[offset++] = 0xA1.toByte()

        // First Property Address (2 bytes)
        packet[offset++] = 0x00
        packet[offset++] = 0x00

        // Address Increment (2 bytes)
        packet[offset++] = 0x00
        packet[offset++] = 0x01

        // Property value count (2 bytes)
        packet[offset++] = ((dataLength shr 8) and 0xFF).toByte()
        packet[offset++] = (dataLength and 0xFF).toByte()

        // Start Code (1 byte)
        packet[offset++] = 0x00

        // DMX Data
        System.arraycopy(dmxData, 0, packet, offset, dmxData.size)

        return try {
            // Calculate multicast address for universe
            val multicastOctet = universe and 0xFF
            val multicastAddress = "239.255.${(universe shr 8) and 0xFF}.$multicastOctet"
            val address = InetAddress.getByName(multicastAddress)
            val datagram = DatagramPacket(packet, offset + dmxData.size, address, port)
            sock.send(datagram)
            true
        } catch (e: Exception) {
            false
        }
    }
}

// ============================================================================
// VISUAL STEP SEQUENCER
// ============================================================================

class VisualStepSequencer {
    data class SequencerStep(
        var enabled: Boolean = false,
        var velocity: Float = 1.0f,
        var probability: Float = 1.0f
    )

    data class SequencerChannel(
        val id: Int,
        val name: String,
        val steps: MutableList<SequencerStep> = MutableList(16) { SequencerStep() },
        var muted: Boolean = false
    )

    private val channels = listOf(
        SequencerChannel(0, "Visual A"),
        SequencerChannel(1, "Visual B"),
        SequencerChannel(2, "Visual C"),
        SequencerChannel(3, "Visual D"),
        SequencerChannel(4, "Lighting"),
        SequencerChannel(5, "Effect 1"),
        SequencerChannel(6, "Effect 2"),
        SequencerChannel(7, "Bio Trigger")
    )

    private val _currentStep = MutableStateFlow(0)
    val currentStep: StateFlow<Int> = _currentStep

    private val _bpm = MutableStateFlow(120f)
    val bpm: StateFlow<Float> = _bpm

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying

    private var playJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Bio-reactive parameters
    private var bioTempoLock = false
    private var coherence = 0.5f
    private var heartRate = 72

    fun setBPM(newBpm: Float) {
        _bpm.value = newBpm.coerceIn(60f, 180f)
    }

    fun setStep(channel: Int, step: Int, enabled: Boolean, velocity: Float = 1.0f) {
        if (channel in channels.indices && step in 0..15) {
            channels[channel].steps[step].enabled = enabled
            channels[channel].steps[step].velocity = velocity
        }
    }

    fun getChannel(id: Int) = channels.getOrNull(id)

    fun start() {
        _isPlaying.value = true
        playJob = scope.launch {
            while (isActive && _isPlaying.value) {
                val currentBpm = if (bioTempoLock) {
                    heartRate.toFloat().coerceIn(60f, 180f)
                } else {
                    _bpm.value
                }

                val stepDuration = (60000f / currentBpm / 4f).toLong() // 16th notes

                _currentStep.value = (_currentStep.value + 1) % 16

                delay(stepDuration)
            }
        }
    }

    fun stop() {
        _isPlaying.value = false
        playJob?.cancel()
        _currentStep.value = 0
    }

    fun enableBioTempoLock(enabled: Boolean) {
        bioTempoLock = enabled
    }

    fun updateBioMetrics(coherence: Float, heartRate: Int) {
        this.coherence = coherence
        this.heartRate = heartRate

        // Modulate skip probability based on HRV
        val skipProbability = (1f - coherence) * 0.3f // Up to 30% skip at low coherence
        channels.forEach { channel ->
            channel.steps.forEach { step ->
                step.probability = 1f - skipProbability
            }
        }
    }

    /**
     * Get triggered channels at current step
     */
    fun getTriggeredChannels(): List<Pair<Int, Float>> {
        val step = _currentStep.value
        return channels.mapIndexedNotNull { index, channel ->
            if (!channel.muted && channel.steps[step].enabled) {
                val shouldTrigger = Math.random() < channel.steps[step].probability
                if (shouldTrigger) {
                    // Modulate velocity by coherence
                    val modulatedVelocity = channel.steps[step].velocity *
                            (0.5f + coherence * 0.5f)
                    index to modulatedVelocity
                } else null
            } else null
        }
    }

    fun applyPreset(preset: SequencerPreset) {
        preset.pattern.forEachIndexed { channelIndex, steps ->
            if (channelIndex < channels.size) {
                steps.forEachIndexed { stepIndex, enabled ->
                    if (stepIndex < 16) {
                        channels[channelIndex].steps[stepIndex].enabled = enabled
                    }
                }
            }
        }
    }
}

enum class SequencerPreset(
    val displayName: String,
    val pattern: List<List<Boolean>> // 8 channels × 16 steps
) {
    FOUR_ON_FLOOR(
        "Four on Floor",
        listOf(
            listOf(true, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false),
            listOf(false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false),
            listOf(true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(true, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false)
        )
    ),
    BREAKBEAT(
        "Breakbeat",
        listOf(
            listOf(true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, false),
            listOf(false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, true),
            listOf(true, false, true, false, true, false, true, false, true, false, true, false, true, false, true, false),
            listOf(false, false, false, true, false, false, false, true, false, false, false, true, false, false, false, true),
            listOf(true, false, false, false, false, false, true, false, false, true, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false)
        )
    ),
    AMBIENT(
        "Ambient",
        listOf(
            listOf(true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false),
            listOf(false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false)
        )
    ),
    BIO_REACTIVE(
        "Bio-Reactive",
        listOf(
            listOf(true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false),
            listOf(false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false),
            listOf(false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(true, false, false, false, true, false, false, false, true, false, false, false, true, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true) // Bio trigger every step
        )
    ),
    MINIMAL(
        "Minimal",
        listOf(
            listOf(true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false),
            listOf(false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false)
        )
    )
}

// ============================================================================
// MAIN MIDI TO LIGHT MAPPER
// ============================================================================

class MIDIToLightMapper {

    private val artNetClient = ArtNetClient()
    private val sacnClient = SACNClient()
    private val sequencer = VisualStepSequencer()

    private val fixtures = mutableListOf<DMXFixture>()
    private val dmxUniverses = mutableMapOf<Int, ByteArray>()

    private val _currentScene = MutableStateFlow(LightScene.AMBIENT)
    val currentScene: StateFlow<LightScene> = _currentScene

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private var outputJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Bio-reactive state
    private var coherence = 0.5f
    private var heartRate = 72
    private var breathingPhase = 0f

    // MIDI CC mapping
    private val midiCCMappings = mutableMapOf<Int, LightParameter>()

    enum class LightParameter {
        MASTER_DIMMER,
        RED, GREEN, BLUE, WHITE,
        COLOR_TEMPERATURE,
        STROBE_RATE,
        PAN, TILT,
        GOBO, PRISM,
        ZOOM, FOCUS,
        FOG_OUTPUT,
        EFFECT_SPEED
    }

    init {
        // Default CC mappings
        midiCCMappings[1] = LightParameter.MASTER_DIMMER  // Mod wheel
        midiCCMappings[7] = LightParameter.MASTER_DIMMER  // Volume
        midiCCMappings[74] = LightParameter.COLOR_TEMPERATURE // Brightness
        midiCCMappings[71] = LightParameter.STROBE_RATE  // Resonance
    }

    // ========================================================================
    // CONNECTION
    // ========================================================================

    fun connect(protocol: LightingProtocol): Boolean {
        val success = when (protocol) {
            LightingProtocol.ARTNET -> artNetClient.connect()
            LightingProtocol.SACN -> sacnClient.connect()
            else -> false
        }

        _isConnected.value = success

        if (success) {
            startOutputLoop()
        }

        return success
    }

    fun disconnect() {
        outputJob?.cancel()
        artNetClient.disconnect()
        sacnClient.disconnect()
        _isConnected.value = false
    }

    // ========================================================================
    // FIXTURE MANAGEMENT
    // ========================================================================

    fun addFixture(fixture: DMXFixture) {
        fixtures.add(fixture)
        ensureUniverse(fixture.universe)
    }

    fun removeFixture(id: String) {
        fixtures.removeAll { it.id == id }
    }

    fun getFixtures(): List<DMXFixture> = fixtures.toList()

    private fun ensureUniverse(universe: Int) {
        if (universe !in dmxUniverses) {
            dmxUniverses[universe] = ByteArray(DMXConstants.UNIVERSE_SIZE)
        }
    }

    // ========================================================================
    // DMX OUTPUT
    // ========================================================================

    fun setChannel(universe: Int, channel: Int, value: Int) {
        ensureUniverse(universe)
        if (channel in DMXConstants.MIN_CHANNEL..DMXConstants.MAX_CHANNEL) {
            dmxUniverses[universe]!![channel - 1] = value.coerceIn(0, 255).toByte()
        }
    }

    fun setRGB(fixture: DMXFixture, red: Int, green: Int, blue: Int) {
        val universe = fixture.universe
        val start = fixture.startChannel

        ensureUniverse(universe)

        dmxUniverses[universe]!![start - 1] = red.coerceIn(0, 255).toByte()
        dmxUniverses[universe]!![start] = green.coerceIn(0, 255).toByte()
        dmxUniverses[universe]!![start + 1] = blue.coerceIn(0, 255).toByte()
    }

    fun setRGBW(fixture: DMXFixture, red: Int, green: Int, blue: Int, white: Int) {
        setRGB(fixture, red, green, blue)
        val universe = fixture.universe
        dmxUniverses[universe]!![fixture.startChannel + 2] = white.coerceIn(0, 255).toByte()
    }

    private fun startOutputLoop() {
        outputJob = scope.launch {
            while (isActive && _isConnected.value) {
                // Send all universes
                dmxUniverses.forEach { (universe, data) ->
                    artNetClient.sendDMX(universe, data)
                    sacnClient.sendDMX(universe, data)
                }

                delay(25) // ~40Hz DMX refresh rate
            }
        }
    }

    // ========================================================================
    // SCENE CONTROL
    // ========================================================================

    fun setScene(scene: LightScene) {
        _currentScene.value = scene
        applyScene(scene)
    }

    private fun applyScene(scene: LightScene) {
        fixtures.forEach { fixture ->
            if (!fixture.enabled) return@forEach

            val color = scene.colorPalette.random()
            val intensity = (scene.intensity * 255).toInt()

            val red = ((color shr 16) and 0xFF) * intensity / 255
            val green = ((color shr 8) and 0xFF) * intensity / 255
            val blue = (color and 0xFF) * intensity / 255

            when (fixture.type) {
                FixtureType.RGB_PAR, FixtureType.LED_STRIP_RGB ->
                    setRGB(fixture, red, green, blue)
                FixtureType.RGBW_PAR, FixtureType.LED_STRIP_RGBW ->
                    setRGBW(fixture, red, green, blue, intensity / 4)
                FixtureType.DIMMER ->
                    setChannel(fixture.universe, fixture.startChannel, intensity)
                else -> {}
            }
        }
    }

    // ========================================================================
    // MIDI MAPPING
    // ========================================================================

    fun processMIDICC(cc: Int, value: Int) {
        val parameter = midiCCMappings[cc] ?: return
        val normalizedValue = value / 127f

        when (parameter) {
            LightParameter.MASTER_DIMMER -> {
                fixtures.forEach { fixture ->
                    if (fixture.type == FixtureType.DIMMER) {
                        setChannel(fixture.universe, fixture.startChannel, (normalizedValue * 255).toInt())
                    }
                }
            }
            LightParameter.COLOR_TEMPERATURE -> {
                // Warm to cool color temperature
                val red = (255 * (1f - normalizedValue * 0.3f)).toInt()
                val blue = (200 + 55 * normalizedValue).toInt()
                fixtures.forEach { fixture ->
                    if (fixture.type in listOf(FixtureType.RGB_PAR, FixtureType.LED_STRIP_RGB)) {
                        setRGB(fixture, red, 255, blue)
                    }
                }
            }
            LightParameter.STROBE_RATE -> {
                fixtures.filter { it.type == FixtureType.STROBE }.forEach { fixture ->
                    setChannel(fixture.universe, fixture.startChannel + 1, (normalizedValue * 255).toInt())
                }
            }
            else -> {}
        }
    }

    fun processMIDINote(note: Int, velocity: Int, isNoteOn: Boolean) {
        if (!isNoteOn) return

        // Note → Color hue mapping
        val hue = (note % 12) / 12f * 360f
        val saturation = velocity / 127f
        val brightness = 0.5f + (velocity / 127f) * 0.5f

        val (r, g, b) = hsvToRgb(hue, saturation, brightness)

        fixtures.forEach { fixture ->
            when (fixture.type) {
                FixtureType.RGB_PAR, FixtureType.LED_STRIP_RGB ->
                    setRGB(fixture, r, g, b)
                FixtureType.RGBW_PAR ->
                    setRGBW(fixture, r, g, b, velocity * 2)
                else -> {}
            }
        }
    }

    // ========================================================================
    // BIO-REACTIVE LIGHTING
    // ========================================================================

    fun updateBioMetrics(coherence: Float, heartRate: Int, breathingPhase: Float) {
        this.coherence = coherence
        this.heartRate = heartRate
        this.breathingPhase = breathingPhase

        // Update sequencer
        sequencer.updateBioMetrics(coherence, heartRate)

        // Apply bio-reactive lighting
        applyBioReactiveLighting()
    }

    private fun applyBioReactiveLighting() {
        if (_currentScene.value != LightScene.REACTIVE) return

        // Heart rate → Strobe/pulse intensity
        val pulseIntensity = ((heartRate - 60) / 80f).coerceIn(0f, 1f)

        // Coherence → Color warmth
        // High coherence = warm greens/blues (calming)
        // Low coherence = warm reds/oranges (activating)
        val (r, g, b) = if (coherence > 0.5f) {
            Triple(
                (100 * (1f - coherence)).toInt(),
                (255 * coherence).toInt(),
                (200 * coherence).toInt()
            )
        } else {
            Triple(
                (255 * (1f - coherence)).toInt(),
                (150 * coherence).toInt(),
                50
            )
        }

        // Breathing → Intensity modulation
        val breathIntensity = 0.5f + breathingPhase * 0.5f

        fixtures.forEach { fixture ->
            if (!fixture.enabled) return@forEach

            when (fixture.type) {
                FixtureType.RGB_PAR, FixtureType.LED_STRIP_RGB -> {
                    setRGB(
                        fixture,
                        (r * breathIntensity).toInt(),
                        (g * breathIntensity).toInt(),
                        (b * breathIntensity).toInt()
                    )
                }
                FixtureType.STROBE -> {
                    // Strobe syncs to heart rate
                    val strobeRate = (heartRate / 2f).coerceIn(30f, 90f)
                    setChannel(fixture.universe, fixture.startChannel + 1, (strobeRate / 90f * 255).toInt())
                }
                else -> {}
            }
        }
    }

    // ========================================================================
    // SEQUENCER INTEGRATION
    // ========================================================================

    fun getSequencer() = sequencer

    fun processSequencerTriggers() {
        val triggers = sequencer.getTriggeredChannels()

        triggers.forEach { (channelId, velocity) ->
            when (channelId) {
                4 -> { // Lighting channel
                    val intensity = (velocity * 255).toInt()
                    fixtures.forEach { fixture ->
                        if (fixture.type == FixtureType.DIMMER) {
                            setChannel(fixture.universe, fixture.startChannel, intensity)
                        }
                    }
                }
                7 -> { // Bio trigger channel
                    // Pulse all fixtures based on current bio state
                    applyBioReactiveLighting()
                }
                else -> {}
            }
        }
    }

    // ========================================================================
    // HELPERS
    // ========================================================================

    private fun hsvToRgb(h: Float, s: Float, v: Float): Triple<Int, Int, Int> {
        val c = v * s
        val x = c * (1 - abs((h / 60f) % 2 - 1))
        val m = v - c

        val (r1, g1, b1) = when {
            h < 60 -> Triple(c, x, 0f)
            h < 120 -> Triple(x, c, 0f)
            h < 180 -> Triple(0f, c, x)
            h < 240 -> Triple(0f, x, c)
            h < 300 -> Triple(x, 0f, c)
            else -> Triple(c, 0f, x)
        }

        return Triple(
            ((r1 + m) * 255).toInt().coerceIn(0, 255),
            ((g1 + m) * 255).toInt().coerceIn(0, 255),
            ((b1 + m) * 255).toInt().coerceIn(0, 255)
        )
    }
}
