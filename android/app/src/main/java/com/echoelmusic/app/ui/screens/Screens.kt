package com.echoelmusic.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.echoelmusic.app.EchoelmusicApplication
import com.echoelmusic.app.audio.AudioEngine

/**
 * Synth Screen - Main polyphonic synthesizer
 */
@Composable
fun SynthScreen() {
    var filterCutoff by remember { mutableFloatStateOf(5000f) }
    var filterRes by remember { mutableFloatStateOf(0.3f) }
    var oscMix by remember { mutableFloatStateOf(0.5f) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            "Polyphonic Synthesizer",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Filter section
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Filter", style = MaterialTheme.typography.titleMedium)

                Text("Cutoff: ${filterCutoff.toInt()} Hz")
                Slider(
                    value = filterCutoff,
                    onValueChange = {
                        filterCutoff = it
                        EchoelmusicApplication.audioEngine.setParameter(
                            AudioEngine.Params.FILTER_CUTOFF, it
                        )
                    },
                    valueRange = 20f..20000f
                )

                Text("Resonance: ${(filterRes * 100).toInt()}%")
                Slider(
                    value = filterRes,
                    onValueChange = {
                        filterRes = it
                        EchoelmusicApplication.audioEngine.setParameter(
                            AudioEngine.Params.FILTER_RESONANCE, it
                        )
                    },
                    valueRange = 0f..1f
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Oscillator section
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Oscillators", style = MaterialTheme.typography.titleMedium)

                Text("Osc Mix: ${(oscMix * 100).toInt()}%")
                Slider(
                    value = oscMix,
                    onValueChange = {
                        oscMix = it
                        EchoelmusicApplication.audioEngine.setParameter(
                            AudioEngine.Params.OSC2_MIX, it
                        )
                    },
                    valueRange = 0f..1f
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Simple keyboard
        Text("Touch to play", style = MaterialTheme.typography.labelMedium)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            val notes = listOf(60, 62, 64, 65, 67, 69, 71, 72) // C major scale
            notes.forEach { note ->
                Button(
                    onClick = {
                        EchoelmusicApplication.audioEngine.noteOn(note, 100)
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text(note.toString())
                }
            }
        }
    }
}

/**
 * TR-808 Screen - 808 Bass with pitch glide
 */
@Composable
fun TR808Screen() {
    var decay by remember { mutableFloatStateOf(1.5f) }
    var drive by remember { mutableFloatStateOf(0.2f) }
    var glideTime by remember { mutableFloatStateOf(0.08f) }
    var glideRange by remember { mutableFloatStateOf(-12f) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            "TR-808 Bass",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(24.dp))

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Decay: ${String.format("%.2f", decay)}s")
                Slider(
                    value = decay,
                    onValueChange = {
                        decay = it
                        EchoelmusicApplication.audioEngine.set808Parameter(
                            AudioEngine.Params.BASS_DECAY, it
                        )
                    },
                    valueRange = 0.1f..5f
                )

                Text("Drive: ${(drive * 100).toInt()}%")
                Slider(
                    value = drive,
                    onValueChange = {
                        drive = it
                        EchoelmusicApplication.audioEngine.set808Parameter(
                            AudioEngine.Params.BASS_DRIVE, it
                        )
                    },
                    valueRange = 0f..1f
                )

                Text("Glide Time: ${String.format("%.0f", glideTime * 1000)}ms")
                Slider(
                    value = glideTime,
                    onValueChange = {
                        glideTime = it
                        EchoelmusicApplication.audioEngine.set808Parameter(
                            AudioEngine.Params.BASS_GLIDE_TIME, it
                        )
                    },
                    valueRange = 0f..0.5f
                )

                Text("Glide Range: ${glideRange.toInt()} semitones")
                Slider(
                    value = glideRange,
                    onValueChange = {
                        glideRange = it
                        EchoelmusicApplication.audioEngine.set808Parameter(
                            AudioEngine.Params.BASS_GLIDE_RANGE, it
                        )
                    },
                    valueRange = -24f..0f
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Bass trigger buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf(36, 38, 40, 41, 43).forEach { note ->
                Button(
                    onClick = {
                        EchoelmusicApplication.audioEngine.trigger808(note, 127)
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("${note}")
                }
            }
        }
    }
}

/**
 * Stem Separation Screen
 */
@Composable
fun StemSeparationScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.Tune,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            "AI Stem Separation",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            "Import audio to separate vocals, drums, bass, and other instruments",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(onClick = { /* Import audio */ }) {
            Icon(Icons.Default.FileOpen, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Import Audio")
        }
    }
}

/**
 * Bio-Reactive Screen
 */
@Composable
fun BioReactiveScreen() {
    val bioEngine = EchoelmusicApplication.bioReactiveEngine
    val heartRate by bioEngine.heartRate.collectAsState()
    val hrv by bioEngine.hrv.collectAsState()
    val coherence by bioEngine.coherence.collectAsState()
    val isConnected by bioEngine.isConnected.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            "Bio-Reactive Control",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Connection status
        Card(
            colors = CardDefaults.cardColors(
                containerColor = if (isConnected)
                    MaterialTheme.colorScheme.primaryContainer
                else
                    MaterialTheme.colorScheme.errorContainer
            )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    if (isConnected) Icons.Default.CheckCircle else Icons.Default.Error,
                    contentDescription = null
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    if (isConnected) "Health Connect Active" else "Health Connect Unavailable"
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Bio metrics
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            BioMetricCard(
                title = "Heart Rate",
                value = "${heartRate.toInt()}",
                unit = "BPM",
                icon = Icons.Default.Favorite,
                modifier = Modifier.weight(1f)
            )

            BioMetricCard(
                title = "HRV",
                value = "${hrv.toInt()}",
                unit = "ms",
                icon = Icons.Default.Timeline,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        BioMetricCard(
            title = "Coherence",
            value = "${(coherence * 100).toInt()}",
            unit = "%",
            icon = Icons.Default.Waves,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            "Bio-Audio Mapping",
            style = MaterialTheme.typography.titleMedium
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            "HRV → Filter Cutoff\nHeart Rate → LFO Rate\nCoherence → 808 Decay",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
fun BioMetricCard(
    title: String,
    value: String,
    unit: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Spacer(modifier = Modifier.height(8.dp))
            Text(title, style = MaterialTheme.typography.labelMedium)
            Text(
                "$value $unit",
                style = MaterialTheme.typography.headlineSmall
            )
        }
    }
}

/**
 * Quantum AI Screen
 */
@Composable
fun QuantumAIScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            "Quantum AI Generation",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(24.dp))

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Available Algorithms", style = MaterialTheme.typography.titleMedium)

                Spacer(modifier = Modifier.height(8.dp))

                listOf(
                    "Quantum Annealing" to "Global optimization",
                    "Grover's Search" to "Pattern matching",
                    "VQE Neural Network" to "Prediction",
                    "Quantum Entanglement" to "Multi-user sync"
                ).forEach { (name, desc) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Check,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(name, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                desc,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = { /* Generate */ },
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(Icons.Default.AutoAwesome, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Generate Quantum Composition")
        }
    }
}

/**
 * Settings Screen
 */
@Composable
fun SettingsScreen() {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        item {
            Text(
                "Settings",
                style = MaterialTheme.typography.headlineMedium
            )

            Spacer(modifier = Modifier.height(24.dp))
        }

        item {
            Text("Audio", style = MaterialTheme.typography.titleMedium)

            ListItem(
                headlineContent = { Text("Buffer Size") },
                supportingContent = { Text("192 frames (~4ms)") },
                leadingContent = { Icon(Icons.Default.Speed, null) }
            )

            ListItem(
                headlineContent = { Text("Sample Rate") },
                supportingContent = { Text("48000 Hz") },
                leadingContent = { Icon(Icons.Default.GraphicEq, null) }
            )
        }

        item {
            HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))
            Text("MIDI", style = MaterialTheme.typography.titleMedium)

            ListItem(
                headlineContent = { Text("USB MIDI") },
                supportingContent = { Text("Auto-connect enabled") },
                leadingContent = { Icon(Icons.Default.Usb, null) }
            )

            ListItem(
                headlineContent = { Text("Bluetooth MIDI") },
                supportingContent = { Text("Scan for devices") },
                leadingContent = { Icon(Icons.Default.Bluetooth, null) }
            )
        }

        item {
            HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))
            Text("Bio-Reactive", style = MaterialTheme.typography.titleMedium)

            ListItem(
                headlineContent = { Text("Health Connect") },
                supportingContent = { Text("Manage permissions") },
                leadingContent = { Icon(Icons.Default.Favorite, null) }
            )
        }
    }
}
