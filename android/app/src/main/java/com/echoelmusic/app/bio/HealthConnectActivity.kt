package com.echoelmusic.app.bio

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.echoelmusic.app.ui.theme.EchoelmusicTheme

/**
 * Activity to show Health Connect permissions rationale
 */
class HealthConnectActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            EchoelmusicTheme {
                HealthConnectPermissionsScreen(
                    onDismiss = { finish() }
                )
            }
        }
    }
}

@Composable
fun HealthConnectPermissionsScreen(onDismiss: () -> Unit) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                "Health Connect Permissions",
                style = MaterialTheme.typography.headlineMedium
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                "Echoelmusic uses Health Connect to read your heart rate and HRV data for bio-reactive audio features.",
                style = MaterialTheme.typography.bodyLarge
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                "This data is used locally to modulate audio parameters and is never uploaded or shared.",
                style = MaterialTheme.typography.bodyMedium
            )

            Spacer(modifier = Modifier.height(24.dp))

            Button(onClick = onDismiss) {
                Text("Got it")
            }
        }
    }
}
