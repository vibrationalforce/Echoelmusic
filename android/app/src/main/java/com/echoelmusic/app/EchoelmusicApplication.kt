package com.echoelmusic.app

import android.app.Application
import android.util.Log
import com.echoelmusic.app.audio.AudioEngine
import com.echoelmusic.app.midi.MidiManager
import com.echoelmusic.app.bio.BioReactiveEngine

/**
 * Echoelmusic Application
 * Bio-Reactive Audio-Visual Platform for Android
 *
 * Features:
 * - Ultra-low-latency audio via Oboe (AAudio/OpenSL ES)
 * - MIDI 2.0 support with USB and Bluetooth
 * - Health Connect integration for bio-reactive features
 * - Quantum-inspired AI audio generation
 */
class EchoelmusicApplication : Application() {

    companion object {
        private const val TAG = "Echoelmusic"

        // Singleton instances
        lateinit var audioEngine: AudioEngine
            private set
        lateinit var midiManager: MidiManager
            private set
        lateinit var bioReactiveEngine: BioReactiveEngine
            private set

        // Native library loaded flag
        var isNativeLoaded = false
            private set
    }

    override fun onCreate() {
        super.onCreate()

        Log.i(TAG, "========================================")
        Log.i(TAG, "  ECHOELMUSIC - Bio-Reactive Platform")
        Log.i(TAG, "  Version: ${BuildConfig.VERSION_NAME}")
        Log.i(TAG, "========================================")

        // Load native audio engine
        loadNativeLibraries()

        // Initialize audio engine
        audioEngine = AudioEngine(this)
        Log.i(TAG, "Audio Engine initialized")

        // Initialize MIDI manager
        midiManager = MidiManager(this)
        Log.i(TAG, "MIDI Manager initialized")

        // Initialize bio-reactive engine
        bioReactiveEngine = BioReactiveEngine(this)
        Log.i(TAG, "Bio-Reactive Engine initialized")

        // Connect systems
        connectSystems()

        Log.i(TAG, "All systems operational")
    }

    private fun loadNativeLibraries() {
        try {
            System.loadLibrary("echoelmusic")
            isNativeLoaded = true
            Log.i(TAG, "Native library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Failed to load native library: ${e.message}")
            isNativeLoaded = false
        }
    }

    private fun connectSystems() {
        // Connect MIDI to audio engine
        midiManager.setNoteCallback { note, velocity, isNoteOn ->
            if (isNoteOn) {
                audioEngine.noteOn(note, velocity)
            } else {
                audioEngine.noteOff(note)
            }
        }

        // Connect bio data to audio modulation
        bioReactiveEngine.setHeartRateCallback { hr, hrv, coherence ->
            audioEngine.updateBioData(hr, hrv, coherence)
        }
    }

    override fun onTerminate() {
        super.onTerminate()
        audioEngine.shutdown()
        midiManager.shutdown()
        bioReactiveEngine.shutdown()
    }
}
