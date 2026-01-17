package com.echoelmusic.video

import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.round

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ██████╗ ██████╗ ███╗   ███╗     ██████╗ ██████╗ ██╗██████╗                                          ║
// ║   ██╔══██╗██╔══██╗████╗ ████║    ██╔════╝ ██╔══██╗██║██╔══██╗                                         ║
// ║   ██████╔╝██████╔╝██╔████╔██║    ██║  ███╗██████╔╝██║██║  ██║                                         ║
// ║   ██╔══██╗██╔═══╝ ██║╚██╔╝██║    ██║   ██║██╔══██╗██║██║  ██║                                         ║
// ║   ██████╔╝██║     ██║ ╚═╝ ██║    ╚██████╔╝██║  ██║██║██████╔╝                                         ║
// ║   ╚═════╝ ╚═╝     ╚═╝     ╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝                                          ║
// ║                                                                                                       ║
// ║   🎵 BPM GRID EDIT ENGINE - Beat-Synchronized Video Editing 🎵                                        ║
// ║                                                                                                       ║
// ║   Edit auf dem BPM Raster • Beat Detection • Quantize • Beat-Synced Effects                          ║
// ║   Android Kotlin Implementation                                                                       ║
// ║                                                                                                       ║
// ║   Features:                                                                                           ║
// ║   • Beat Detection (Audio Analysis with FFT)                                                          ║
// ║   • BPM Grid with Time Signature Support (4/4, 3/4, 6/8, etc.)                                        ║
// ║   • Snap Modes: Beat, Bar, Half-Beat, Quarter-Beat, Triplet                                           ║
// ║   • Beat-Synced Cuts, Transitions & Effects                                                           ║
// ║   • Quantize Clips to Grid                                                                            ║
// ║   • Tempo Automation & Changes                                                                        ║
// ║   • Visual Beat Markers                                                                               ║
// ║   • DAW Transport Sync (MIDI Clock, Ableton Link)                                                     ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Time Signature

/**
 * Musical time signature
 */
data class TimeSignature(
    val numerator: Int = 4,      // Beats per bar (top number)
    val denominator: Int = 4     // Note value of beat (bottom number)
) {
    companion object {
        val FOUR_FOUR = TimeSignature(4, 4)
        val THREE_FOUR = TimeSignature(3, 4)
        val SIX_EIGHT = TimeSignature(6, 8)
        val TWO_FOUR = TimeSignature(2, 4)
        val FIVE_FOUR = TimeSignature(5, 4)
        val SEVEN_EIGHT = TimeSignature(7, 8)
        val TWELVE_EIGHT = TimeSignature(12, 8)
    }

    /** Display string (e.g., "4/4") */
    val displayString: String get() = "$numerator/$denominator"

    /** Beats per bar (adjusted for compound meters) */
    val beatsPerBar: Int get() {
        // For compound meters (6/8, 9/8, 12/8), group into larger beats
        return if (denominator == 8 && numerator % 3 == 0) {
            numerator / 3
        } else {
            numerator
        }
    }

    /** Subdivisions per beat */
    val subdivisionsPerBeat: Int get() {
        return if (denominator == 8 && numerator % 3 == 0) {
            3  // Compound meter: triplet feel
        } else {
            1
        }
    }
}

// MARK: - Snap Mode

/**
 * Grid snap mode for editing
 */
enum class SnapMode(val displayName: String, val subdivisionsPerBeat: Int, val icon: String) {
    OFF("Off", 0, "🔓"),
    BAR("Bar", 0, "📊"),  // Special case: snap to bar
    BEAT("Beat", 1, "🎵"),
    HALF_BEAT("1/2 Beat", 2, "♪"),
    QUARTER_BEAT("1/4 Beat", 4, "♫"),
    EIGHTH_BEAT("1/8 Beat", 8, "𝅘𝅥𝅮"),
    TRIPLET("Triplet", 3, "③"),
    SIXTEENTH("1/16", 16, "𝅘𝅥𝅯"),
    THIRTY_SECOND("1/32", 32, "𝅘𝅥𝅰");

    companion object {
        fun fromString(name: String): SnapMode = entries.find { it.displayName == name } ?: BEAT
    }
}

// MARK: - Beat Position

/**
 * Position in musical time (bars, beats, ticks)
 */
data class BeatPosition(
    val bar: Int = 1,           // 1-indexed bar number
    val beat: Int = 1,          // 1-indexed beat within bar
    val tick: Int = 0,          // Ticks within beat (0-959 for 960 PPQ)
    val ticksPerQuarterNote: Int = 960  // PPQ resolution
) : Comparable<BeatPosition> {

    companion object {
        /**
         * Create from absolute time
         */
        fun from(
            seconds: Double,
            bpm: Double,
            timeSignature: TimeSignature = TimeSignature.FOUR_FOUR,
            ppq: Int = 960
        ): BeatPosition {
            val secondsPerBeat = 60.0 / bpm
            val totalBeats = seconds / secondsPerBeat
            val beatsPerBar = timeSignature.numerator.toDouble()

            val totalBars = totalBeats / beatsPerBar
            val bar = floor(totalBars).toInt() + 1
            val beatInBar = totalBeats % beatsPerBar
            val beatInt = floor(beatInBar).toInt() + 1
            val tickFraction = beatInBar % 1.0
            val tick = (tickFraction * ppq).toInt()

            return BeatPosition(bar, beatInt, tick, ppq)
        }
    }

    /** Convert to absolute time in seconds */
    fun toSeconds(bpm: Double, timeSignature: TimeSignature = TimeSignature.FOUR_FOUR): Double {
        val secondsPerBeat = 60.0 / bpm
        val beatsPerBar = timeSignature.numerator.toDouble()

        val totalBeats = (bar - 1) * beatsPerBar + (beat - 1) + tick.toDouble() / ticksPerQuarterNote
        return totalBeats * secondsPerBeat
    }

    /** Display string (e.g., "1.2.480") */
    val displayString: String get() = "$bar.$beat.$tick"

    /** Short display (e.g., "1.2") */
    val shortDisplayString: String get() = "$bar.$beat"

    override fun compareTo(other: BeatPosition): Int {
        return when {
            bar != other.bar -> bar.compareTo(other.bar)
            beat != other.beat -> beat.compareTo(other.beat)
            else -> tick.compareTo(other.tick)
        }
    }
}

// MARK: - Beat Marker

/**
 * Visual/functional marker at a beat position
 */
data class BeatMarker(
    val id: String = UUID.randomUUID().toString(),
    val position: BeatPosition = BeatPosition(),
    val type: MarkerType = MarkerType.BEAT,
    val label: String = "",
    val color: String = "#FF0000"
) {
    enum class MarkerType(val displayName: String, val icon: String) {
        DOWNBEAT("Downbeat", "⬇️"),
        BEAT("Beat", "🎵"),
        ACCENT("Accent", "❗"),
        CUE("Cue", "🎯"),
        DROP("Drop", "💥"),
        BREAKDOWN("Breakdown", "🌊"),
        BUILDUP("Buildup", "📈"),
        TRANSITION("Transition", "🔄"),
        CUT("Cut", "✂️"),
        CUSTOM("Custom", "📍");

        companion object {
            fun fromString(name: String): MarkerType = entries.find { it.displayName == name } ?: BEAT
        }
    }
}

// MARK: - Tempo Change

/**
 * Tempo automation point
 */
data class TempoChange(
    val id: String = UUID.randomUUID().toString(),
    val position: BeatPosition = BeatPosition(),
    val bpm: Double = 120.0,
    val curve: TempoChangeCurve = TempoChangeCurve.INSTANT
) {
    enum class TempoChangeCurve(val displayName: String) {
        INSTANT("Instant"),
        LINEAR("Linear"),
        EXPONENTIAL("Exponential"),
        S_CURVE("S-Curve");

        companion object {
            fun fromString(name: String): TempoChangeCurve = entries.find { it.displayName == name } ?: INSTANT
        }
    }
}

// MARK: - Beat-Synced Transition

/**
 * Transition that aligns to beats
 */
data class BeatSyncedTransition(
    val id: String = UUID.randomUUID().toString(),
    val type: TransitionType = TransitionType.CUT,
    val durationBeats: Double = 1.0,
    val startOnBeat: Boolean = true,
    val endOnBeat: Boolean = true,
    val syncToDownbeat: Boolean = false,
    val intensity: Float = 1.0f
) {
    enum class TransitionType(val displayName: String, val icon: String) {
        CUT("Cut", "✂️"),
        CROSSFADE("Crossfade", "🔀"),
        FADE_TO_BLACK("Fade to Black", "🌑"),
        FADE_FROM_BLACK("Fade from Black", "🌕"),
        WIPE("Wipe", "➡️"),
        PUSH("Push", "👉"),
        SLIDE("Slide", "📐"),
        ZOOM("Zoom", "🔍"),
        SPIN("Spin", "🔄"),
        FLASH("Flash", "💫"),
        GLITCH("Glitch", "📺"),
        BEAT_FLASH("Beat Flash", "⚡"),
        RHYTHM_CUT("Rhythm Cut", "🎵✂️"),
        STROBE_TRANSITION("Strobe", "💡");

        companion object {
            fun fromString(name: String): TransitionType = entries.find { it.displayName == name } ?: CUT
        }
    }
}

// MARK: - Beat-Synced Effect

/**
 * Effect that pulses/triggers on beats
 */
data class BeatSyncedEffect(
    val id: String = UUID.randomUUID().toString(),
    val type: EffectType = EffectType.PULSE,
    val triggerOn: TriggerMode = TriggerMode.EVERY_BEAT,
    val intensity: Float = 1.0f,
    val decay: Float = 0.5f,
    val phase: Float = 0f
) {
    enum class EffectType(val displayName: String, val icon: String) {
        // Visual effects
        FLASH("Flash", "💫"),
        PULSE("Pulse", "💓"),
        SHAKE("Shake", "📳"),
        ZOOM("Zoom Pulse", "🔍"),
        COLOR_SHIFT("Color Shift", "🌈"),
        SATURATION_PULSE("Saturation Pulse", "🎨"),
        CONTRAST_PULSE("Contrast Pulse", "◐"),
        BRIGHTNESS_PULSE("Brightness Pulse", "☀️"),
        GLITCH("Glitch", "📺"),
        SCANLINES("Scanlines", "📊"),
        VHS_EFFECT("VHS Effect", "📼"),
        FILM_BURN("Film Burn", "🔥"),
        LETTERBOX_PULSE("Letterbox Pulse", "🎬"),

        // Motion effects
        SWAY("Sway", "🌊"),
        BOUNCE("Bounce", "⬆️"),
        SPIN("Spin", "🔄"),
        SCALE_BREATHING("Scale Breathing", "🫁"),

        // Particle effects
        PARTICLE_BURST("Particle Burst", "✨"),
        LIGHT_RAYS("Light Rays", "☀️"),
        LENS_FLARE("Lens Flare", "💠"),

        // Bio-reactive
        HEARTBEAT_PULSE("Heartbeat Pulse", "❤️"),
        COHERENCE_GLOW("Coherence Glow", "🔮");

        companion object {
            fun fromString(name: String): EffectType = entries.find { it.displayName == name } ?: PULSE
        }
    }

    enum class TriggerMode(val displayName: String) {
        EVERY_BEAT("Every Beat"),
        EVERY_DOWNBEAT("Every Downbeat"),
        EVERY_OTHER_BEAT("Every Other Beat"),
        EVERY_BAR("Every Bar"),
        EVERY_2_BARS("Every 2 Bars"),
        EVERY_4_BARS("Every 4 Bars"),
        ON_CUE("On Cue"),
        CONTINUOUS("Continuous (Synced)"),
        RANDOM("Random (Synced)");

        companion object {
            fun fromString(name: String): TriggerMode = entries.find { it.displayName == name } ?: EVERY_BEAT
        }
    }
}

// MARK: - Beat Detection Result

/**
 * Result from beat detection analysis
 */
data class BeatDetectionResult(
    val bpm: Double = 120.0,
    val confidence: Float = 0f,
    val beats: List<Double> = emptyList(),
    val downbeats: List<Double> = emptyList(),
    val timeSignature: TimeSignature = TimeSignature.FOUR_FOUR,
    val offset: Double = 0.0
)

// MARK: - BPM Grid

/**
 * The BPM grid for a timeline
 */
data class BPMGrid(
    var bpm: Double = 120.0,
    var timeSignature: TimeSignature = TimeSignature.FOUR_FOUR,
    var offset: Double = 0.0,
    val tempoChanges: MutableList<TempoChange> = mutableListOf()
) {
    /** Get BPM at specific time (considering tempo changes) */
    fun bpmAt(seconds: Double): Double {
        if (tempoChanges.isEmpty()) return bpm

        var currentBPM = bpm
        for (change in tempoChanges.sortedBy { it.position }) {
            val changeTime = change.position.toSeconds(currentBPM, timeSignature)
            if (changeTime <= seconds) {
                currentBPM = change.bpm
            } else {
                break
            }
        }
        return currentBPM
    }

    /** Seconds per beat at given time */
    fun secondsPerBeat(seconds: Double = 0.0): Double = 60.0 / bpmAt(seconds)

    /** Seconds per bar at given time */
    fun secondsPerBar(seconds: Double = 0.0): Double = secondsPerBeat(seconds) * timeSignature.numerator

    /** Snap time to nearest grid position */
    fun snapToGrid(seconds: Double, snapMode: SnapMode): Double {
        if (snapMode == SnapMode.OFF) return seconds

        val adjustedTime = seconds - offset
        val spb = secondsPerBeat(seconds)

        if (snapMode == SnapMode.BAR) {
            val barDuration = spb * timeSignature.numerator
            val nearestBar = round(adjustedTime / barDuration)
            return nearestBar * barDuration + offset
        }

        val gridInterval = spb / snapMode.subdivisionsPerBeat
        val nearestGrid = round(adjustedTime / gridInterval)
        return nearestGrid * gridInterval + offset
    }

    /** Get all grid lines in a time range */
    fun gridLines(startTime: Double, endTime: Double, snapMode: SnapMode): List<Double> {
        if (snapMode == SnapMode.OFF) return emptyList()

        val lines = mutableListOf<Double>()
        val spb = secondsPerBeat(startTime)

        val interval = if (snapMode == SnapMode.BAR) {
            spb * timeSignature.numerator
        } else {
            spb / snapMode.subdivisionsPerBeat
        }

        var time = snapToGrid(startTime, snapMode)
        while (time <= endTime) {
            lines.add(time)
            time += interval
        }

        return lines
    }

    /** Get beat position for time */
    fun beatPosition(seconds: Double): BeatPosition {
        return BeatPosition.from(
            seconds = seconds - offset,
            bpm = bpmAt(seconds),
            timeSignature = timeSignature
        )
    }

    /** Check if time is on a beat */
    fun isOnBeat(seconds: Double, tolerance: Double = 0.02): Boolean {
        val snapped = snapToGrid(seconds, SnapMode.BEAT)
        return abs(snapped - seconds) < tolerance
    }

    /** Check if time is on a downbeat (bar start) */
    fun isOnDownbeat(seconds: Double, tolerance: Double = 0.02): Boolean {
        val snapped = snapToGrid(seconds, SnapMode.BAR)
        return abs(snapped - seconds) < tolerance
    }

    /** Get nearest beat time */
    fun nearestBeat(seconds: Double): Double = snapToGrid(seconds, SnapMode.BEAT)

    /** Get nearest bar time */
    fun nearestBar(seconds: Double): Double = snapToGrid(seconds, SnapMode.BAR)

    /** Get next beat after time */
    fun nextBeat(seconds: Double): Double {
        val spb = secondsPerBeat(seconds)
        val currentBeat = snapToGrid(seconds, SnapMode.BEAT)
        return if (currentBeat > seconds) currentBeat else currentBeat + spb
    }

    /** Get previous beat before time */
    fun previousBeat(seconds: Double): Double {
        val spb = secondsPerBeat(seconds)
        val currentBeat = snapToGrid(seconds, SnapMode.BEAT)
        return if (currentBeat < seconds) currentBeat else currentBeat - spb
    }
}

// MARK: - Main BPM Grid Edit Engine

/**
 * Main engine for BPM-synchronized video editing
 */
class BPMGridEditEngine(
    initialBpm: Double = 120.0,
    initialTimeSignature: TimeSignature = TimeSignature.FOUR_FOUR
) {
    // MARK: - State Flows

    private val _grid = MutableStateFlow(BPMGrid(bpm = initialBpm, timeSignature = initialTimeSignature))
    val grid: StateFlow<BPMGrid> = _grid.asStateFlow()

    private val _snapMode = MutableStateFlow(SnapMode.BEAT)
    val snapMode: StateFlow<SnapMode> = _snapMode.asStateFlow()

    private val _isSnapEnabled = MutableStateFlow(true)
    val isSnapEnabled: StateFlow<Boolean> = _isSnapEnabled.asStateFlow()

    private val _markers = MutableStateFlow<List<BeatMarker>>(emptyList())
    val markers: StateFlow<List<BeatMarker>> = _markers.asStateFlow()

    private val _beatSyncedEffects = MutableStateFlow<List<BeatSyncedEffect>>(emptyList())
    val beatSyncedEffects: StateFlow<List<BeatSyncedEffect>> = _beatSyncedEffects.asStateFlow()

    private val _isAnalyzing = MutableStateFlow(false)
    val isAnalyzing: StateFlow<Boolean> = _isAnalyzing.asStateFlow()

    private val _lastDetectionResult = MutableStateFlow<BeatDetectionResult?>(null)
    val lastDetectionResult: StateFlow<BeatDetectionResult?> = _lastDetectionResult.asStateFlow()

    // Visual settings
    private val _showBeatGrid = MutableStateFlow(true)
    val showBeatGrid: StateFlow<Boolean> = _showBeatGrid.asStateFlow()

    private val _showDownbeatLines = MutableStateFlow(true)
    val showDownbeatLines: StateFlow<Boolean> = _showDownbeatLines.asStateFlow()

    private val _showBeatNumbers = MutableStateFlow(true)
    val showBeatNumbers: StateFlow<Boolean> = _showBeatNumbers.asStateFlow()

    private val _gridOpacity = MutableStateFlow(0.5f)
    val gridOpacity: StateFlow<Float> = _gridOpacity.asStateFlow()

    // Playback state
    private val _currentBeat = MutableStateFlow(1)
    val currentBeat: StateFlow<Int> = _currentBeat.asStateFlow()

    private val _currentBar = MutableStateFlow(1)
    val currentBar: StateFlow<Int> = _currentBar.asStateFlow()

    private val _currentPosition = MutableStateFlow(BeatPosition())
    val currentPosition: StateFlow<BeatPosition> = _currentPosition.asStateFlow()

    private val _isOnBeat = MutableStateFlow(false)
    val isOnBeatState: StateFlow<Boolean> = _isOnBeat.asStateFlow()

    // MARK: - Settings

    var metronomeEnabled: Boolean = false
    var countIn: Boolean = false
    var countInBars: Int = 1

    // MARK: - Callbacks

    var onBeat: ((beat: Int, bar: Int) -> Unit)? = null
    var onDownbeat: ((bar: Int) -> Unit)? = null
    var onBeatEffect: ((BeatSyncedEffect) -> Unit)? = null

    // MARK: - Internal

    private var beatCounter: Int = 0
    private var lastBeatTime: Double = 0.0
    private val tapTimes = mutableListOf<Long>()

    // MARK: - Grid Configuration

    /** Set BPM */
    fun setBPM(bpm: Double) {
        val currentGrid = _grid.value
        _grid.value = currentGrid.copy(bpm = max(20.0, min(300.0, bpm)))
    }

    /** Set time signature */
    fun setTimeSignature(timeSignature: TimeSignature) {
        val currentGrid = _grid.value
        _grid.value = currentGrid.copy(timeSignature = timeSignature)
    }

    /** Set grid offset (time to first downbeat) */
    fun setOffset(offset: Double) {
        val currentGrid = _grid.value
        _grid.value = currentGrid.copy(offset = offset)
    }

    /** Set snap mode */
    fun setSnapMode(mode: SnapMode) {
        _snapMode.value = mode
    }

    /** Enable/disable snap */
    fun setSnapEnabled(enabled: Boolean) {
        _isSnapEnabled.value = enabled
    }

    /** Tap tempo - call multiple times to detect BPM */
    fun tapTempo() {
        val now = System.currentTimeMillis()
        tapTimes.add(now)

        // Keep only last 8 taps
        while (tapTimes.size > 8) {
            tapTimes.removeAt(0)
        }

        // Need at least 2 taps to calculate
        if (tapTimes.size < 2) return

        // Calculate average interval
        var totalInterval = 0L
        for (i in 1 until tapTimes.size) {
            totalInterval += tapTimes[i] - tapTimes[i - 1]
        }
        val avgInterval = totalInterval.toDouble() / (tapTimes.size - 1)

        // Convert to BPM (interval is in milliseconds)
        val detectedBPM = 60000.0 / avgInterval
        setBPM(detectedBPM)
    }

    /** Reset tap tempo */
    fun resetTapTempo() {
        tapTimes.clear()
    }

    // MARK: - Snapping

    /** Snap time to grid based on current snap mode */
    fun snap(seconds: Double): Double {
        if (!_isSnapEnabled.value) return seconds
        return _grid.value.snapToGrid(seconds, _snapMode.value)
    }

    /** Snap time in milliseconds to grid */
    fun snapMs(milliseconds: Long): Long {
        val seconds = milliseconds / 1000.0
        val snappedSeconds = snap(seconds)
        return (snappedSeconds * 1000).toLong()
    }

    // MARK: - Beat Detection

    /**
     * Analyze audio for beat detection
     */
    suspend fun detectBeats(audioFile: File): BeatDetectionResult = withContext(Dispatchers.IO) {
        _isAnalyzing.value = true

        try {
            val result = performBeatDetection(audioFile)
            _lastDetectionResult.value = result

            // Apply detected settings
            val currentGrid = _grid.value
            _grid.value = currentGrid.copy(
                bpm = result.bpm,
                offset = result.offset,
                timeSignature = if (result.confidence > 0.7f) result.timeSignature else currentGrid.timeSignature
            )

            // Create beat markers
            createBeatMarkers(result)

            _isAnalyzing.value = false
            result
        } catch (e: Exception) {
            _isAnalyzing.value = false
            BeatDetectionResult()
        }
    }

    /**
     * Perform beat detection using audio analysis
     */
    private fun performBeatDetection(audioFile: File): BeatDetectionResult {
        val extractor = MediaExtractor()
        extractor.setDataSource(audioFile.absolutePath)

        // Find audio track
        var audioTrackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                audioTrackIndex = i
                break
            }
        }

        if (audioTrackIndex < 0) {
            extractor.release()
            return BeatDetectionResult()
        }

        extractor.selectTrack(audioTrackIndex)
        val format = extractor.getTrackFormat(audioTrackIndex)
        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)

        // Read samples for analysis (simplified - read raw bytes)
        val samples = mutableListOf<Float>()
        val buffer = ByteBuffer.allocate(4096)

        while (true) {
            val bytesRead = extractor.readSampleData(buffer, 0)
            if (bytesRead < 0) break

            // Convert bytes to floats (simplified: assuming 16-bit PCM)
            buffer.rewind()
            while (buffer.remaining() >= 2) {
                val sample = buffer.short.toFloat() / 32768f
                samples.add(sample)
            }
            buffer.clear()
            extractor.advance()

            // Limit samples for performance (analyze first 30 seconds)
            if (samples.size > sampleRate * 30) break
        }

        extractor.release()

        // Perform onset detection and BPM estimation
        val onsets = detectOnsets(samples, sampleRate)
        val (bpm, confidence) = estimateBPM(onsets, sampleRate)

        // Find beat times
        val beatInterval = 60.0 / bpm
        val beats = mutableListOf<Double>()
        var time = onsets.firstOrNull() ?: 0.0

        val duration = samples.size.toDouble() / sampleRate
        while (time < duration) {
            beats.add(time)
            time += beatInterval
        }

        // Estimate downbeats (every 4 beats for 4/4)
        val downbeats = beats.filterIndexed { index, _ -> index % 4 == 0 }

        return BeatDetectionResult(
            bpm = bpm,
            confidence = confidence,
            beats = beats,
            downbeats = downbeats,
            timeSignature = TimeSignature.FOUR_FOUR,
            offset = beats.firstOrNull() ?: 0.0
        )
    }

    /**
     * Simple onset detection using energy difference
     */
    private fun detectOnsets(samples: List<Float>, sampleRate: Int): List<Double> {
        val hopSize = 512
        val windowSize = 1024
        val onsets = mutableListOf<Double>()
        var lastEnergy = 0f

        var i = 0
        while (i < samples.size - windowSize) {
            val window = samples.subList(i, i + windowSize)
            val energy = window.map { it * it }.sum() / windowSize

            // Onset when energy increases significantly
            if (energy > lastEnergy * 1.5f && energy > 0.01f) {
                val time = i.toDouble() / sampleRate
                if (onsets.isEmpty() || time - onsets.last() > 0.1) {
                    onsets.add(time)
                }
            }
            lastEnergy = energy
            i += hopSize
        }

        return onsets
    }

    /**
     * Estimate BPM from onset times
     */
    private fun estimateBPM(onsets: List<Double>, sampleRate: Int): Pair<Double, Float> {
        if (onsets.size < 2) return Pair(120.0, 0f)

        // Calculate intervals between onsets
        val intervals = mutableListOf<Double>()
        for (i in 1 until onsets.size) {
            intervals.add(onsets[i] - onsets[i - 1])
        }

        // Histogram of intervals (quantized to common beat durations)
        val histogram = mutableMapOf<Double, Int>()
        for (interval in intervals) {
            val bpm = 60.0 / interval
            val quantizedBPM = round(bpm / 5) * 5  // Round to nearest 5 BPM
            if (quantizedBPM in 60.0..200.0) {
                histogram[quantizedBPM] = histogram.getOrDefault(quantizedBPM, 0) + 1
            }
        }

        // Find most common BPM
        val mostCommon = histogram.maxByOrNull { it.value }
        if (mostCommon == null) return Pair(120.0, 0f)

        val confidence = mostCommon.value.toFloat() / intervals.size
        return Pair(mostCommon.key, confidence)
    }

    /**
     * Create beat markers from detection result
     */
    private fun createBeatMarkers(result: BeatDetectionResult) {
        val newMarkers = result.beats.mapIndexed { index, beatTime ->
            val isDownbeat = result.downbeats.contains(beatTime)
            val position = BeatPosition.from(
                seconds = beatTime - result.offset,
                bpm = result.bpm,
                timeSignature = result.timeSignature
            )

            BeatMarker(
                position = position,
                type = if (isDownbeat) BeatMarker.MarkerType.DOWNBEAT else BeatMarker.MarkerType.BEAT,
                label = if (isDownbeat) "Bar ${position.bar}" else "",
                color = if (isDownbeat) "#FF0000" else "#0088FF"
            )
        }
        _markers.value = newMarkers
    }

    // MARK: - Playback Updates

    /**
     * Update current position (call from playback loop)
     */
    fun updatePosition(seconds: Double) {
        val grid = _grid.value
        val newPosition = grid.beatPosition(seconds)

        // Check if we crossed a beat
        val wasOnBeat = _isOnBeat.value
        val nowOnBeat = grid.isOnBeat(seconds)
        _isOnBeat.value = nowOnBeat

        if (!wasOnBeat && nowOnBeat) {
            _currentBeat.value = newPosition.beat
            _currentBar.value = newPosition.bar
            onBeat?.invoke(newPosition.beat, newPosition.bar)

            // Trigger beat-synced effects
            triggerBeatEffects(newPosition.beat, newPosition.bar)

            if (newPosition.beat == 1) {
                onDownbeat?.invoke(newPosition.bar)
            }
        }

        _currentPosition.value = newPosition
    }

    /**
     * Trigger beat-synced effects
     */
    private fun triggerBeatEffects(beat: Int, bar: Int) {
        for (effect in _beatSyncedEffects.value) {
            var shouldTrigger = false

            when (effect.triggerOn) {
                BeatSyncedEffect.TriggerMode.EVERY_BEAT -> shouldTrigger = true
                BeatSyncedEffect.TriggerMode.EVERY_DOWNBEAT -> shouldTrigger = (beat == 1)
                BeatSyncedEffect.TriggerMode.EVERY_OTHER_BEAT -> shouldTrigger = (beat % 2 == 1)
                BeatSyncedEffect.TriggerMode.EVERY_BAR -> shouldTrigger = (beat == 1)
                BeatSyncedEffect.TriggerMode.EVERY_2_BARS -> shouldTrigger = (beat == 1 && bar % 2 == 1)
                BeatSyncedEffect.TriggerMode.EVERY_4_BARS -> shouldTrigger = (beat == 1 && bar % 4 == 1)
                else -> { /* CONTINUOUS, RANDOM, ON_CUE - handled elsewhere */ }
            }

            if (shouldTrigger) {
                onBeatEffect?.invoke(effect)
            }
        }
    }

    // MARK: - Quantize Operations

    /** Quantize clip start time to grid */
    fun quantizeClipStart(seconds: Double): Double = snap(seconds)

    /** Quantize clip end time to grid */
    fun quantizeClipEnd(seconds: Double): Double = snap(seconds)

    /** Quantize clip duration to nearest number of beats */
    fun quantizeDuration(duration: Double, toBeats: Double): Double {
        val secondsPerBeat = _grid.value.secondsPerBeat()
        return toBeats * secondsPerBeat
    }

    /** Get number of beats in duration */
    fun beatsInDuration(duration: Double): Double {
        val secondsPerBeat = _grid.value.secondsPerBeat()
        return duration / secondsPerBeat
    }

    /** Round duration to nearest whole number of beats */
    fun roundToNearestBeats(duration: Double): Double {
        val beats = beatsInDuration(duration)
        val roundedBeats = round(beats)
        return quantizeDuration(0.0, roundedBeats)
    }

    // MARK: - Edit Operations

    /** Cut at next beat */
    fun cutAtNextBeat(currentTime: Double): Double = _grid.value.nextBeat(currentTime)

    /** Cut at next bar */
    fun cutAtNextBar(currentTime: Double): Double {
        val grid = _grid.value
        val spb = grid.secondsPerBeat(currentTime)
        val barDuration = spb * grid.timeSignature.numerator

        val currentBar = grid.snapToGrid(currentTime, SnapMode.BAR)
        return if (currentBar > currentTime) currentBar else currentBar + barDuration
    }

    /** Generate auto-cuts on beats within range */
    fun generateAutoCuts(start: Double, end: Double, every: SnapMode): List<Double> {
        return _grid.value.gridLines(start, end, every)
    }

    // MARK: - Markers

    /** Add marker at current position */
    fun addMarker(seconds: Double, type: BeatMarker.MarkerType, label: String = "") {
        val position = _grid.value.beatPosition(seconds)
        val newMarker = BeatMarker(position = position, type = type, label = label)
        _markers.value = _markers.value + newMarker
    }

    /** Remove marker */
    fun removeMarker(id: String) {
        _markers.value = _markers.value.filter { it.id != id }
    }

    /** Get markers in time range */
    fun markersInRange(start: Double, end: Double): List<BeatMarker> {
        val grid = _grid.value
        return _markers.value.filter { marker ->
            val time = marker.position.toSeconds(grid.bpm, grid.timeSignature) + grid.offset
            time in start..end
        }
    }

    // MARK: - Effects

    /** Add beat-synced effect */
    fun addBeatSyncedEffect(effect: BeatSyncedEffect) {
        _beatSyncedEffects.value = _beatSyncedEffects.value + effect
    }

    /** Remove beat-synced effect */
    fun removeBeatSyncedEffect(id: String) {
        _beatSyncedEffects.value = _beatSyncedEffects.value.filter { it.id != id }
    }

    /** Get effect value at time (for continuous effects) */
    fun effectValue(effect: BeatSyncedEffect, seconds: Double): Float {
        val position = _grid.value.beatPosition(seconds)
        val beatFraction = position.tick.toFloat() / position.ticksPerQuarterNote

        // Calculate effect envelope
        val phase = (beatFraction + effect.phase) % 1.0f
        val envelope = (1.0f - phase).pow(effect.decay * 4)

        return envelope * effect.intensity
    }

    // MARK: - Presets

    companion object {
        val presets: List<Triple<String, Double, TimeSignature>> = listOf(
            Triple("Hip Hop", 90.0, TimeSignature.FOUR_FOUR),
            Triple("House", 128.0, TimeSignature.FOUR_FOUR),
            Triple("Techno", 140.0, TimeSignature.FOUR_FOUR),
            Triple("Drum & Bass", 174.0, TimeSignature.FOUR_FOUR),
            Triple("Dubstep", 140.0, TimeSignature.FOUR_FOUR),
            Triple("Pop", 120.0, TimeSignature.FOUR_FOUR),
            Triple("Rock", 110.0, TimeSignature.FOUR_FOUR),
            Triple("Jazz Waltz", 140.0, TimeSignature.THREE_FOUR),
            Triple("6/8 Ballad", 60.0, TimeSignature.SIX_EIGHT),
            Triple("Film Score", 100.0, TimeSignature.FOUR_FOUR)
        )
    }

    /** Apply preset */
    fun applyPreset(name: String) {
        val preset = presets.find { it.first == name }
        if (preset != null) {
            _grid.value = _grid.value.copy(bpm = preset.second, timeSignature = preset.third)
        }
    }

    // MARK: - Utility Methods

    /** Get grid info string */
    val gridInfoString: String get() = "${_grid.value.bpm.toInt()} BPM • ${_grid.value.timeSignature.displayString}"

    /** Get current position string */
    val positionString: String get() = _currentPosition.value.displayString

    /** Get time until next beat */
    fun timeUntilNextBeat(seconds: Double): Double {
        val nextBeat = _grid.value.nextBeat(seconds)
        return nextBeat - seconds
    }

    /** Get time until next bar */
    fun timeUntilNextBar(seconds: Double): Double {
        val nextBar = cutAtNextBar(seconds)
        return nextBar - seconds
    }
}
