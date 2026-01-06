package com.echoelmusic.app

import android.app.Application
import android.util.Log

/**
 * Echoelmusic Application
 * Bio-Reactive Audio-Visual Platform for Android
 *
 * ARCHITECTURE NOTE:
 * Engine instances are now managed by EchoelmusicViewModel following
 * proper Android architecture guidelines. Activities/Fragments should
 * obtain the ViewModel via:
 *
 *     val viewModel: EchoelmusicViewModel by viewModels()
 *
 * This ensures:
 * - Proper lifecycle management
 * - Survives configuration changes
 * - No memory leaks
 * - Scoped coroutines
 *
 * Nobel Prize Multitrillion Dollar Company Loop - Production Ready
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

        // Native library loaded flag - safe to keep in companion
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

        Log.i(TAG, "Application initialized - use EchoelmusicViewModel for engine access")
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

    override fun onTerminate() {
        super.onTerminate()
        Log.i(TAG, "Application terminated")
    }
}
