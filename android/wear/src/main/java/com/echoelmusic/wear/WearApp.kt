/**
 * WearApp.kt
 * Echoelmusic Wear OS Companion App
 *
 * Features:
 * - Real-time HRV & coherence display
 * - Quick session controls
 * - Phone-watch communication via Data Layer
 * - Complications for watch faces
 * - Health Services integration
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.*
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.echoelmusic.wear.presentation.*
import com.echoelmusic.wear.theme.EchoelmusicWearTheme

class WearMainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            EchoelmusicWearApp()
        }
    }
}

@Composable
fun EchoelmusicWearApp() {
    EchoelmusicWearTheme {
        val navController = rememberSwipeDismissableNavController()
        val viewModel: WearViewModel = viewModel()

        SwipeDismissableNavHost(
            navController = navController,
            startDestination = "home"
        ) {
            composable("home") {
                HomeScreen(
                    viewModel = viewModel,
                    onNavigateToSession = { navController.navigate("session") },
                    onNavigateToSettings = { navController.navigate("settings") },
                    onNavigateToHistory = { navController.navigate("history") }
                )
            }

            composable("session") {
                SessionScreen(
                    viewModel = viewModel,
                    onBack = { navController.popBackStack() }
                )
            }

            composable("settings") {
                SettingsScreen(
                    viewModel = viewModel,
                    onBack = { navController.popBackStack() }
                )
            }

            composable("history") {
                HistoryScreen(
                    viewModel = viewModel,
                    onBack = { navController.popBackStack() }
                )
            }
        }
    }
}

// ============================================================================
// MARK: - Home Screen
// ============================================================================

@Composable
fun HomeScreen(
    viewModel: WearViewModel,
    onNavigateToSession: () -> Unit,
    onNavigateToSettings: () -> Unit,
    onNavigateToHistory: () -> Unit
) {
    val bioData by viewModel.bioData.collectAsState()
    val isConnected by viewModel.isPhoneConnected.collectAsState()

    Scaffold(
        timeText = { TimeText() },
        vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) }
    ) {
        ScalingLazyColumn(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 32.dp)
        ) {
            // Coherence Ring
            item {
                CoherenceRing(
                    coherence = bioData.coherence,
                    heartRate = bioData.heartRate,
                    modifier = Modifier.size(120.dp)
                )
            }

            // HRV Display
            item {
                HrvDisplay(
                    hrv = bioData.hrv,
                    coherenceLevel = bioData.coherenceLevel
                )
            }

            // Quick Session Button
            item {
                Chip(
                    onClick = onNavigateToSession,
                    label = { Text("Start Session") },
                    icon = {
                        Icon(
                            imageVector = androidx.compose.material.icons.Icons.Default.PlayArrow,
                            contentDescription = null
                        )
                    },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = MaterialTheme.colors.primary
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // History
            item {
                Chip(
                    onClick = onNavigateToHistory,
                    label = { Text("History") },
                    icon = {
                        Icon(
                            imageVector = androidx.compose.material.icons.Icons.Default.History,
                            contentDescription = null
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Settings
            item {
                Chip(
                    onClick = onNavigateToSettings,
                    label = { Text("Settings") },
                    icon = {
                        Icon(
                            imageVector = androidx.compose.material.icons.Icons.Default.Settings,
                            contentDescription = null
                        )
                    },
                    colors = ChipDefaults.secondaryChipColors(),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Connection Status
            item {
                ConnectionStatus(isConnected = isConnected)
            }
        }
    }
}

// ============================================================================
// MARK: - Coherence Ring Component
// ============================================================================

@Composable
fun CoherenceRing(
    coherence: Float,
    heartRate: Int,
    modifier: Modifier = Modifier
) {
    val coherenceColor = when {
        coherence >= 0.7f -> Color(0xFF4CAF50) // Green - High
        coherence >= 0.4f -> Color(0xFFFFC107) // Yellow - Medium
        else -> Color(0xFFFF5722) // Orange - Low
    }

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        // Background ring
        CircularProgressIndicator(
            progress = 1f,
            modifier = Modifier.fillMaxSize(),
            strokeWidth = 8.dp,
            indicatorColor = Color.DarkGray.copy(alpha = 0.3f)
        )

        // Coherence ring
        CircularProgressIndicator(
            progress = coherence,
            modifier = Modifier.fillMaxSize(),
            strokeWidth = 8.dp,
            indicatorColor = coherenceColor
        )

        // Heart rate in center
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "❤️",
                fontSize = 20.sp
            )
            Text(
                text = "$heartRate",
                fontSize = 28.sp,
                color = Color.White
            )
            Text(
                text = "BPM",
                fontSize = 10.sp,
                color = Color.Gray
            )
        }
    }
}

// ============================================================================
// MARK: - HRV Display Component
// ============================================================================

@Composable
fun HrvDisplay(
    hrv: Float,
    coherenceLevel: CoherenceLevel
) {
    Card(
        onClick = { },
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "HRV",
                fontSize = 12.sp,
                color = Color.Gray
            )
            Text(
                text = String.format("%.1f ms", hrv),
                fontSize = 24.sp,
                color = Color.White
            )
            Text(
                text = coherenceLevel.displayName,
                fontSize = 14.sp,
                color = coherenceLevel.color
            )
        }
    }
}

// ============================================================================
// MARK: - Connection Status
// ============================================================================

@Composable
fun ConnectionStatus(isConnected: Boolean) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
        modifier = Modifier.padding(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(
                    color = if (isConnected) Color.Green else Color.Red,
                    shape = androidx.compose.foundation.shape.CircleShape
                )
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = if (isConnected) "Phone Connected" else "Disconnected",
            fontSize = 12.sp,
            color = Color.Gray
        )
    }
}

// ============================================================================
// MARK: - Session Screen
// ============================================================================

@Composable
fun SessionScreen(
    viewModel: WearViewModel,
    onBack: () -> Unit
) {
    val bioData by viewModel.bioData.collectAsState()
    val sessionState by viewModel.sessionState.collectAsState()
    val sessionDuration by viewModel.sessionDuration.collectAsState()

    Scaffold(
        timeText = { TimeText() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Large Coherence Display
            CoherenceRing(
                coherence = bioData.coherence,
                heartRate = bioData.heartRate,
                modifier = Modifier.size(100.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Session Timer
            Text(
                text = formatDuration(sessionDuration),
                fontSize = 32.sp,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Breathing Guide
            BreathingGuide(
                breathPhase = bioData.breathPhase,
                breathingRate = bioData.breathingRate
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Control Buttons
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                when (sessionState) {
                    SessionState.IDLE -> {
                        Button(
                            onClick = { viewModel.startSession() },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = MaterialTheme.colors.primary
                            )
                        ) {
                            Icon(
                                imageVector = androidx.compose.material.icons.Icons.Default.PlayArrow,
                                contentDescription = "Start"
                            )
                        }
                    }
                    SessionState.RUNNING -> {
                        Button(
                            onClick = { viewModel.pauseSession() },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = Color(0xFFFFC107)
                            )
                        ) {
                            Icon(
                                imageVector = androidx.compose.material.icons.Icons.Default.Pause,
                                contentDescription = "Pause"
                            )
                        }
                        Button(
                            onClick = { viewModel.stopSession() },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = Color(0xFFFF5722)
                            )
                        ) {
                            Icon(
                                imageVector = androidx.compose.material.icons.Icons.Default.Stop,
                                contentDescription = "Stop"
                            )
                        }
                    }
                    SessionState.PAUSED -> {
                        Button(
                            onClick = { viewModel.resumeSession() },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = MaterialTheme.colors.primary
                            )
                        ) {
                            Icon(
                                imageVector = androidx.compose.material.icons.Icons.Default.PlayArrow,
                                contentDescription = "Resume"
                            )
                        }
                        Button(
                            onClick = { viewModel.stopSession() },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = Color(0xFFFF5722)
                            )
                        ) {
                            Icon(
                                imageVector = androidx.compose.material.icons.Icons.Default.Stop,
                                contentDescription = "Stop"
                            )
                        }
                    }
                }
            }
        }
    }
}

// ============================================================================
// MARK: - Breathing Guide
// ============================================================================

@Composable
fun BreathingGuide(
    breathPhase: Float,
    breathingRate: Float
) {
    val phase = when {
        breathPhase < 0.5f -> "Inhale"
        else -> "Exhale"
    }
    val circleSize = (40 + 20 * kotlin.math.sin(breathPhase * kotlin.math.PI * 2)).dp

    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(circleSize)
                .background(
                    color = MaterialTheme.colors.primary.copy(alpha = 0.5f),
                    shape = androidx.compose.foundation.shape.CircleShape
                )
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = phase,
            fontSize = 14.sp,
            color = Color.Gray
        )
    }
}

// ============================================================================
// MARK: - Settings Screen
// ============================================================================

@Composable
fun SettingsScreen(
    viewModel: WearViewModel,
    onBack: () -> Unit
) {
    val settings by viewModel.settings.collectAsState()

    Scaffold(
        timeText = { TimeText() }
    ) {
        ScalingLazyColumn(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = PaddingValues(16.dp)
        ) {
            item {
                Text(
                    text = "Settings",
                    fontSize = 18.sp,
                    color = Color.White,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
            }

            // Haptic Feedback
            item {
                ToggleChip(
                    checked = settings.hapticFeedback,
                    onCheckedChange = { viewModel.updateSettings(settings.copy(hapticFeedback = it)) },
                    label = { Text("Haptic Feedback") },
                    toggleControl = {
                        Switch(
                            checked = settings.hapticFeedback
                        )
                    },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Always-On Display
            item {
                ToggleChip(
                    checked = settings.alwaysOnDisplay,
                    onCheckedChange = { viewModel.updateSettings(settings.copy(alwaysOnDisplay = it)) },
                    label = { Text("Always-On Display") },
                    toggleControl = {
                        Switch(
                            checked = settings.alwaysOnDisplay
                        )
                    },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Breathing Guide
            item {
                ToggleChip(
                    checked = settings.showBreathingGuide,
                    onCheckedChange = { viewModel.updateSettings(settings.copy(showBreathingGuide = it)) },
                    label = { Text("Breathing Guide") },
                    toggleControl = {
                        Switch(
                            checked = settings.showBreathingGuide
                        )
                    },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Session Target Duration
            item {
                Chip(
                    onClick = { /* Show duration picker */ },
                    label = { Text("Target: ${settings.targetDurationMinutes} min") },
                    secondaryLabel = { Text("Session duration") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

// ============================================================================
// MARK: - History Screen
// ============================================================================

@Composable
fun HistoryScreen(
    viewModel: WearViewModel,
    onBack: () -> Unit
) {
    val sessionHistory by viewModel.sessionHistory.collectAsState()

    Scaffold(
        timeText = { TimeText() }
    ) {
        if (sessionHistory.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No sessions yet",
                    color = Color.Gray,
                    textAlign = TextAlign.Center
                )
            }
        } else {
            ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp)
            ) {
                item {
                    Text(
                        text = "Recent Sessions",
                        fontSize = 16.sp,
                        color = Color.White,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }

                items(sessionHistory.size) { index ->
                    val session = sessionHistory[index]
                    SessionHistoryItem(session = session)
                }
            }
        }
    }
}

@Composable
fun SessionHistoryItem(session: SessionSummary) {
    Card(
        onClick = { },
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp)
        ) {
            Text(
                text = session.formattedDate,
                fontSize = 12.sp,
                color = Color.Gray
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = formatDuration(session.durationSeconds),
                    fontSize = 16.sp,
                    color = Color.White
                )
                Text(
                    text = "${(session.avgCoherence * 100).toInt()}%",
                    fontSize = 16.sp,
                    color = session.coherenceLevel.color
                )
            }
        }
    }
}

// ============================================================================
// MARK: - Utility Functions
// ============================================================================

fun formatDuration(seconds: Long): String {
    val minutes = seconds / 60
    val secs = seconds % 60
    return String.format("%02d:%02d", minutes, secs)
}
