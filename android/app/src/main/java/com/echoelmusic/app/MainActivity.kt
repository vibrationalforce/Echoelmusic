package com.echoelmusic.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.echoelmusic.app.ui.EchoelmusicApp
import com.echoelmusic.app.ui.theme.EchoelmusicTheme

/**
 * Main Activity - Echoelmusic Android
 * Jetpack Compose UI with Material 3
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        enableEdgeToEdge()

        setContent {
            EchoelmusicTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    EchoelmusicApp()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        EchoelmusicApplication.audioEngine.start()
        EchoelmusicApplication.midiManager.start()
    }

    override fun onPause() {
        super.onPause()
        // Keep audio running in background if service is active
        if (!EchoelmusicApplication.audioEngine.isServiceRunning) {
            EchoelmusicApplication.audioEngine.stop()
        }
    }
}
