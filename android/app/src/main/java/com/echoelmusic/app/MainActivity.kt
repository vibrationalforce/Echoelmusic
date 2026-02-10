package com.echoelmusic.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.echoelmusic.app.ui.EchoelmusicApp
import com.echoelmusic.app.ui.theme.EchoelmusicTheme
import com.echoelmusic.app.viewmodel.EchoelmusicViewModel

/**
 * Main Activity - Echoelmusic Android
 * Jetpack Compose UI with Material 3
 */
class MainActivity : ComponentActivity() {

    private val viewModel: EchoelmusicViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        enableEdgeToEdge()

        setContent {
            EchoelmusicTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    EchoelmusicApp(viewModel = viewModel)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        viewModel.startAudio()
        viewModel.midiManager.start()
    }

    override fun onPause() {
        super.onPause()
        // Keep audio running in background if service is active
        if (!viewModel.audioEngine.isServiceRunning) {
            viewModel.stopAudio()
        }
    }
}
