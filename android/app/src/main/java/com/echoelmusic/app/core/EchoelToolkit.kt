package com.echoelmusic.app.core

import android.content.Context
import com.echoelmusic.app.audio.AudioEngine
import com.echoelmusic.app.midi.MidiManager
import com.echoelmusic.app.bio.BioReactiveEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * EchoelToolkit — The Master Registry (Android)
 *
 * Kotlin port of the Swift EchoelToolkit from EchoelToolkit.swift.
 * Provides unified access to all tools via EngineBus communication.
 *
 * Architecture mirrors the Swift side:
 * ┌─────────────────────────────────────────┐
 * │          EchoelToolkit (Android)         │
 * │                                         │
 * │  EchoelSynth  EchoelBio  EchoelMIDI    │
 * │       │           │           │         │
 * │       └───────────┴───────────┘         │
 * │              EngineBus                  │
 * └─────────────────────────────────────────┘
 *
 * Currently implements: Synth, Bio, MIDI (core audio pipeline).
 * Remaining tools (Mix, FX, Seq, Vis, Vid, Lux, Net, AI) are stubs
 * ready for implementation.
 */
class EchoelToolkit private constructor(context: Context) {

    companion object {
        @Volatile
        private var instance: EchoelToolkit? = null

        fun getInstance(context: Context): EchoelToolkit {
            return instance ?: synchronized(this) {
                instance ?: EchoelToolkit(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    // Core tools (implemented)
    val synth: EchoelSynth = EchoelSynth(context)
    val bio: EchoelBio = EchoelBio(context)
    val midi: EchoelMidi = EchoelMidi(context)

    // Bus
    val bus: EngineBus = EngineBus

    init {
        // Wire bio → synth via bus
        scope.launch {
            bus.messages.collect { msg ->
                when (msg) {
                    is EngineBus.BusMessage.BioUpdate -> {
                        synth.applyBio(msg.snapshot)
                    }
                    else -> { /* other tools can subscribe here */ }
                }
            }
        }
    }

    val status: String
        get() = "EchoelToolkit Android: Synth=${synth.isPlaying}, Bio=${bio.isStreaming}, ${bus.stats}"
}

/**
 * EchoelSynth — Synthesis engine wrapper
 * Wraps the existing AudioEngine with EchoelToolkit API
 */
class EchoelSynth(context: Context) {

    private val engine = AudioEngine(context)

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: Boolean get() = _isPlaying.value

    fun noteOn(note: Int, velocity: Int) {
        engine.noteOn(note, velocity)
        _isPlaying.value = true
        EngineBus.publishParam("synth", "noteOn", note.toFloat())
    }

    fun noteOff(note: Int) {
        engine.noteOff(note)
        _isPlaying.value = false
    }

    fun start() = engine.start()
    fun stop() = engine.stop()

    /** Apply bio-reactive parameters to synthesis */
    fun applyBio(snapshot: EngineBus.BioSnapshot) {
        // Map coherence + HRV + heart rate to audio parameters
        engine.updateBioData(snapshot.heartRate, snapshot.hrvVariability * 100f, snapshot.coherence)
    }

    fun shutdown() = engine.shutdown()
}

/**
 * EchoelBio — Biometrics hub
 * Wraps the existing BioReactiveEngine with EchoelToolkit API
 */
class EchoelBio(context: Context) {

    private val engine = BioReactiveEngine(context)

    private val _heartRate = MutableStateFlow(70f)
    val heartRate: StateFlow<Float> = _heartRate.asStateFlow()

    private val _coherence = MutableStateFlow(0.5f)
    val coherence: StateFlow<Float> = _coherence.asStateFlow()

    private val _hrvMs = MutableStateFlow(50f)
    val hrvMs: StateFlow<Float> = _hrvMs.asStateFlow()

    var isStreaming = false
        private set

    init {
        // Register providers on bus
        EngineBus.provide("bio.heartRate") { _heartRate.value }
        EngineBus.provide("bio.coherence") { _coherence.value }
        EngineBus.provide("bio.hrvMs") { _hrvMs.value }

        // Wire engine callbacks to bus
        engine.setHeartRateCallback { hr, hrv, coh ->
            _heartRate.value = hr
            _hrvMs.value = hrv
            _coherence.value = coh

            // Broadcast extended bio snapshot
            EngineBus.publishBio(
                EngineBus.BioSnapshot(
                    coherence = coh,
                    heartRate = hr,
                    hrvVariability = (hrv / 100f).coerceIn(0f, 1f)
                )
            )
        }
    }

    fun startStreaming() {
        isStreaming = true
    }

    fun stopStreaming() {
        isStreaming = false
    }

    fun shutdown() = engine.shutdown()
}

/**
 * EchoelMidi — MIDI control hub
 * Wraps the existing MidiManager with EchoelToolkit API
 */
class EchoelMidi(context: Context) {

    private val manager = MidiManager(context)

    fun noteOn(channel: Int, note: Int, velocity: Int) {
        EngineBus.publish(
            EngineBus.BusMessage.Custom(
                topic = "midi.noteOn",
                payload = mapOf("note" to "$note", "vel" to "$velocity", "ch" to "$channel")
            )
        )
    }

    fun controlChange(channel: Int, cc: Int, value: Int) {
        EngineBus.publishParam("midi", "cc$cc", value / 127f)
    }

    fun shutdown() = manager.shutdown()
}
