package com.echoelmusic.app

import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.core.view.WindowCompat
import com.echoelmusic.app.ui.EchoelmusicApp
import com.echoelmusic.app.ui.theme.EchoelmusicTheme
import com.echoelmusic.app.viewmodel.EchoelmusicViewModel

/**
 * LocalViewModel composition local for deep composable access.
 * All UI composables should receive viewModel as parameter (per CLAUDE.md),
 * but this serves as a fallback for deeply nested utility composables.
 */
val LocalEchoelmusicViewModel = staticCompositionLocalOf<EchoelmusicViewModel> {
    error("No EchoelmusicViewModel provided. Pass viewModel as parameter to composables.")
}

/**
 * Main Activity - Echoelmusic Android
 *
 * Bio-Reactive Audio-Visual Platform
 * Jetpack Compose UI with Material 3 + Vaporwave Theme
 *
 * Architecture:
 * - ComponentActivity for Compose
 * - ViewModel by viewModels() (survives config changes)
 * - Edge-to-edge rendering with transparent system bars
 * - Keep screen on during audio sessions
 */
class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private val viewModel: EchoelmusicViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Enable edge-to-edge rendering for immersive Vaporwave experience
        enableEdgeToEdge()

        // Allow drawing behind system bars
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Keep screen on during active audio sessions (battery-conscious)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContent {
            EchoelmusicTheme(darkTheme = true) {
                // Provide ViewModel via CompositionLocal as a safety net
                // Primary access pattern: pass viewModel as parameter
                CompositionLocalProvider(LocalEchoelmusicViewModel provides viewModel) {
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background
                    ) {
                        EchoelmusicApp(viewModel = viewModel)
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            viewModel.startAudio()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start audio on resume", e)
        }
        try {
            viewModel.midiManager.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start MIDI on resume", e)
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            // Keep audio running in background if service is active
            if (!viewModel.audioEngine.isServiceRunning) {
                viewModel.stopAudio()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop audio on pause", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clear keep-screen-on flag
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
