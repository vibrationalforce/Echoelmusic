package com.echoelmusic.app.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.echoelmusic.app.EchoelmusicApplication
import com.echoelmusic.app.ui.screens.*

/**
 * Main Echoelmusic App UI
 * Jetpack Compose with Material 3 Design
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EchoelmusicApp() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Bio-reactive state
    var heartRate by remember { mutableFloatStateOf(70f) }
    var coherence by remember { mutableFloatStateOf(0.5f) }
    var isPlaying by remember { mutableStateOf(false) }

    // Update from bio engine with proper cleanup
    DisposableEffect(Unit) {
        EchoelmusicApplication.bioReactiveEngine.setHeartRateCallback { hr, _, coh ->
            heartRate = hr
            coherence = coh
        }

        // Clean up callback when composable is disposed to prevent memory leaks
        onDispose {
            EchoelmusicApplication.bioReactiveEngine.clearCallback()
        }
    }

    // Animated background based on coherence
    val backgroundColor by animateColorAsState(
        targetValue = when {
            coherence > 0.8f -> Color(0xFF1A237E) // Deep blue - high coherence
            coherence > 0.5f -> Color(0xFF311B92) // Purple - medium coherence
            else -> Color(0xFF4A148C) // Magenta - low coherence
        },
        label = "background"
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.GraphicEq,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            "Echoelmusic",
                            fontWeight = FontWeight.Bold
                        )
                    }
                },
                actions = {
                    // Bio status indicator
                    BioStatusChip(heartRate = heartRate, coherence = coherence)
                    Spacer(modifier = Modifier.width(8.dp))

                    // Settings
                    IconButton(onClick = { navController.navigate("settings") }) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = backgroundColor.copy(alpha = 0.95f)
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = backgroundColor.copy(alpha = 0.95f)
            ) {
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Piano, contentDescription = null) },
                    label = { Text("Synth") },
                    selected = currentRoute == "synth",
                    onClick = { navController.navigate("synth") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Album, contentDescription = null) },
                    label = { Text("808") },
                    selected = currentRoute == "tr808",
                    onClick = { navController.navigate("tr808") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Tune, contentDescription = null) },
                    label = { Text("Stems") },
                    selected = currentRoute == "stems",
                    onClick = { navController.navigate("stems") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.FavoriteBorder, contentDescription = null) },
                    label = { Text("Bio") },
                    selected = currentRoute == "bio",
                    onClick = { navController.navigate("bio") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.AutoAwesome, contentDescription = null) },
                    label = { Text("AI") },
                    selected = currentRoute == "quantum",
                    onClick = { navController.navigate("quantum") }
                )
            }
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = {
                    isPlaying = !isPlaying
                    if (isPlaying) {
                        EchoelmusicApplication.audioEngine.start()
                    } else {
                        EchoelmusicApplication.audioEngine.stop()
                    }
                },
                containerColor = if (isPlaying)
                    MaterialTheme.colorScheme.error
                else
                    MaterialTheme.colorScheme.primary
            ) {
                Icon(
                    if (isPlaying) Icons.Default.Stop else Icons.Default.PlayArrow,
                    contentDescription = if (isPlaying) "Stop" else "Play"
                )
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            backgroundColor,
                            backgroundColor.copy(alpha = 0.7f),
                            Color.Black
                        )
                    )
                )
                .padding(paddingValues)
        ) {
            NavHost(
                navController = navController,
                startDestination = "synth"
            ) {
                composable("synth") { SynthScreen() }
                composable("tr808") { TR808Screen() }
                composable("stems") { StemSeparationScreen() }
                composable("bio") { BioReactiveScreen() }
                composable("quantum") { QuantumAIScreen() }
                composable("settings") { SettingsScreen() }
            }
        }
    }
}

@Composable
fun BioStatusChip(heartRate: Float, coherence: Float) {
    val coherenceColor = when {
        coherence > 0.8f -> Color(0xFF4CAF50) // Green
        coherence > 0.5f -> Color(0xFFFFEB3B) // Yellow
        else -> Color(0xFFFF5722) // Orange
    }

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Heart rate
            Icon(
                Icons.Default.Favorite,
                contentDescription = null,
                tint = Color.Red,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                "${heartRate.toInt()}",
                style = MaterialTheme.typography.labelMedium
            )

            Spacer(modifier = Modifier.width(8.dp))

            // Coherence indicator
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(coherenceColor)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                "${(coherence * 100).toInt()}%",
                style = MaterialTheme.typography.labelMedium
            )
        }
    }
}
