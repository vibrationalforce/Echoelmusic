package com.echoelmusic.app.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.echoelmusic.app.audio.AudioEngine
import com.echoelmusic.app.ui.theme.EchoelColors
import com.echoelmusic.app.viewmodel.BrainwaveState
import com.echoelmusic.app.viewmodel.EchoelmusicViewModel
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

// ================================================================
// Main Dashboard Screen
// ================================================================

/**
 * Main Dashboard Screen
 * Displays: Audio visualizer, bio-metrics (HR, HRV, coherence),
 * master audio controls, and quick-access panels.
 */
@Composable
fun MainDashboardScreen(viewModel: EchoelmusicViewModel) {
    val heartRate by viewModel.heartRate.collectAsState()
    val hrv by viewModel.hrv.collectAsState()
    val coherence by viewModel.coherence.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()
    val masterVolume by viewModel.masterVolume.collectAsState()
    val filterCutoff by viewModel.filterCutoff.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        // Audio Visualizer
        item {
            AudioVisualizerCard(
                isPlaying = isPlaying,
                coherence = coherence,
                heartRate = heartRate
            )
        }

        // Bio-Metrics Row
        item {
            BioMetricsRow(
                heartRate = heartRate,
                hrv = hrv,
                coherence = coherence
            )
        }

        // Master Audio Controls
        item {
            MasterAudioControlsCard(
                viewModel = viewModel,
                isPlaying = isPlaying,
                masterVolume = masterVolume,
                filterCutoff = filterCutoff
            )
        }

        // Bio-Audio Mapping Info
        item {
            BioAudioMappingCard(coherence = coherence)
        }

        // Quick Actions
        item {
            QuickActionsCard(viewModel = viewModel)
        }

        // Bottom spacing
        item {
            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

/**
 * Real-time audio visualizer canvas with waveform animation.
 * Reacts to coherence level and playback state.
 */
@Composable
fun AudioVisualizerCard(
    isPlaying: Boolean,
    coherence: Float,
    heartRate: Float
) {
    val infiniteTransition = rememberInfiniteTransition(label = "visualizer")

    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2f * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = if (isPlaying) 3000 else 6000,
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "phase"
    )

    val amplitude by animateFloatAsState(
        targetValue = if (isPlaying) 0.6f + coherence * 0.4f else 0.1f,
        animationSpec = tween(durationMillis = 800),
        label = "amplitude"
    )

    val waveColor by animateColorAsState(
        targetValue = when {
            coherence > 0.8f -> EchoelColors.neonCyan
            coherence > 0.5f -> EchoelColors.neonPurple
            else -> EchoelColors.neonPink
        },
        animationSpec = tween(durationMillis = 1500),
        label = "waveColor"
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Canvas(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                val width = size.width
                val height = size.height
                val centerY = height / 2f
                val maxAmplitude = height * 0.35f

                // Draw multiple layered waveforms
                for (layer in 0..2) {
                    val layerAlpha = 1f - layer * 0.3f
                    val layerPhaseOffset = layer * 0.8f
                    val layerFreqMultiplier = 1f + layer * 0.5f

                    val path = Path()
                    var firstPoint = true

                    for (x in 0..width.toInt() step 2) {
                        val normalizedX = x / width
                        val waveY = centerY + sin(
                            normalizedX * layerFreqMultiplier * 4f * PI.toFloat() +
                                    phase + layerPhaseOffset
                        ) * maxAmplitude * amplitude *
                                (0.5f + 0.5f * sin(normalizedX * PI.toFloat()))

                        if (firstPoint) {
                            path.moveTo(x.toFloat(), waveY)
                            firstPoint = false
                        } else {
                            path.lineTo(x.toFloat(), waveY)
                        }
                    }

                    drawPath(
                        path = path,
                        color = waveColor.copy(alpha = layerAlpha * 0.7f),
                        style = Stroke(
                            width = (3f - layer).coerceAtLeast(1f),
                            cap = StrokeCap.Round
                        )
                    )
                }

                // Center line
                drawLine(
                    color = EchoelColors.textTertiary.copy(alpha = 0.2f),
                    start = Offset(0f, centerY),
                    end = Offset(width, centerY),
                    strokeWidth = 1f
                )
            }

            // Status label
            Text(
                text = if (isPlaying) "LIVE" else "STANDBY",
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
                    .background(
                        color = if (isPlaying) EchoelColors.neonCyan.copy(alpha = 0.2f)
                                else EchoelColors.bgElevated,
                        shape = RoundedCornerShape(8.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp),
                style = MaterialTheme.typography.labelSmall,
                color = if (isPlaying) EchoelColors.neonCyan else EchoelColors.textTertiary,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

/**
 * Bio-metrics display row with HR, HRV, and coherence cards.
 */
@Composable
fun BioMetricsRow(
    heartRate: Float,
    hrv: Float,
    coherence: Float
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        BioMetricCard(
            title = "Heart Rate",
            value = "${heartRate.toInt()}",
            unit = "BPM",
            icon = Icons.Default.Favorite,
            accentColor = EchoelColors.neonPink,
            modifier = Modifier.weight(1f)
        )
        BioMetricCard(
            title = "HRV",
            value = "${hrv.toInt()}",
            unit = "ms",
            icon = Icons.Default.Timeline,
            accentColor = EchoelColors.neonPurple,
            modifier = Modifier.weight(1f)
        )
        BioMetricCard(
            title = "Coherence",
            value = "${(coherence * 100).toInt()}",
            unit = "%",
            icon = Icons.Default.Waves,
            accentColor = when {
                coherence > 0.8f -> EchoelColors.coherenceHigh
                coherence > 0.5f -> EchoelColors.coherenceMedium
                else -> EchoelColors.coherenceLow
            },
            modifier = Modifier.weight(1f)
        )
    }
}

/**
 * Individual bio-metric display card with icon, value, and unit.
 */
@Composable
fun BioMetricCard(
    title: String,
    value: String,
    unit: String,
    icon: ImageVector,
    accentColor: Color = EchoelColors.neonCyan,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                icon,
                contentDescription = title,
                tint = accentColor,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                title,
                style = MaterialTheme.typography.labelSmall,
                color = EchoelColors.textTertiary
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                value,
                style = MaterialTheme.typography.headlineSmall,
                color = EchoelColors.textPrimary,
                fontWeight = FontWeight.Bold
            )
            Text(
                unit,
                style = MaterialTheme.typography.labelSmall,
                color = accentColor
            )
        }
    }
}

/**
 * Master audio controls card with volume and filter controls.
 */
@Composable
fun MasterAudioControlsCard(
    viewModel: EchoelmusicViewModel,
    isPlaying: Boolean,
    masterVolume: Float,
    filterCutoff: Float
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    "Audio Controls",
                    style = MaterialTheme.typography.titleMedium,
                    color = EchoelColors.neonCyan
                )
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (isPlaying) EchoelColors.neonCyan.copy(alpha = 0.15f)
                            else EchoelColors.bgElevated
                ) {
                    Text(
                        if (isPlaying) "ACTIVE" else "IDLE",
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isPlaying) EchoelColors.neonCyan
                                else EchoelColors.textTertiary,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Master Volume
            Text(
                "Master Volume: ${(masterVolume * 100).toInt()}%",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textSecondary
            )
            Slider(
                value = masterVolume,
                onValueChange = { viewModel.setMasterVolume(it) },
                valueRange = 0f..1f,
                colors = SliderDefaults.colors(
                    thumbColor = EchoelColors.neonCyan,
                    activeTrackColor = EchoelColors.neonCyan,
                    inactiveTrackColor = EchoelColors.bgElevated
                )
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Filter Cutoff
            Text(
                "Filter Cutoff: ${filterCutoff.toInt()} Hz",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textSecondary
            )
            Slider(
                value = filterCutoff,
                onValueChange = { viewModel.setFilterCutoff(it) },
                valueRange = 20f..20000f,
                colors = SliderDefaults.colors(
                    thumbColor = EchoelColors.neonPurple,
                    activeTrackColor = EchoelColors.neonPurple,
                    inactiveTrackColor = EchoelColors.bgElevated
                )
            )
        }
    }
}

/**
 * Card showing how bio signals map to audio parameters.
 */
@Composable
fun BioAudioMappingCard(coherence: Float) {
    val mappingState = when {
        coherence > 0.8f -> "Fibonacci" to "Harmonious spatial field"
        coherence > 0.5f -> "Transitional" to "Adaptive spatial blending"
        else -> "Grid" to "Grounded spatial anchoring"
    }

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Bio-Audio Mapping",
                style = MaterialTheme.typography.titleMedium,
                color = EchoelColors.neonPink
            )
            Spacer(modifier = Modifier.height(12.dp))

            // Current spatial mode
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = EchoelColors.bgElevated
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Grain,
                        contentDescription = null,
                        tint = EchoelColors.neonPurple,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            "Spatial Mode: ${mappingState.first}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = EchoelColors.textPrimary
                        )
                        Text(
                            mappingState.second,
                            style = MaterialTheme.typography.labelSmall,
                            color = EchoelColors.textTertiary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Mapping details
            val mappings = listOf(
                Triple("HRV", "Filter Cutoff", Icons.Default.Timeline),
                Triple("Heart Rate", "LFO Rate", Icons.Default.Favorite),
                Triple("Coherence", "Spatial Geometry", Icons.Default.Waves)
            )
            mappings.forEach { (source, target, icon) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        icon,
                        contentDescription = null,
                        tint = EchoelColors.neonCyan.copy(alpha = 0.7f),
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        source,
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textSecondary,
                        modifier = Modifier.width(80.dp)
                    )
                    Icon(
                        Icons.Default.ArrowForward,
                        contentDescription = null,
                        tint = EchoelColors.textTertiary,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        target,
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.neonCyan
                    )
                }
            }
        }
    }
}

/**
 * Quick action buttons for common tasks.
 */
@Composable
fun QuickActionsCard(viewModel: EchoelmusicViewModel) {
    val binauralEnabled by viewModel.binauralBeatsEnabled.collectAsState()

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Quick Actions",
                style = MaterialTheme.typography.titleMedium,
                color = EchoelColors.neonCyan
            )
            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                QuickActionChip(
                    label = "Binaural",
                    icon = Icons.Default.Waves,
                    isActive = binauralEnabled,
                    activeColor = EchoelColors.neonPurple,
                    onClick = { viewModel.toggleBinauralBeats() },
                    modifier = Modifier.weight(1f)
                )
                QuickActionChip(
                    label = "Record",
                    icon = Icons.Default.FiberManualRecord,
                    isActive = false,
                    activeColor = EchoelColors.sunset,
                    onClick = { /* Recording not yet wired */ },
                    modifier = Modifier.weight(1f)
                )
                QuickActionChip(
                    label = "Share",
                    icon = Icons.Default.Share,
                    isActive = false,
                    activeColor = EchoelColors.mint,
                    onClick = { /* Sharing not yet wired */ },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
fun QuickActionChip(
    label: String,
    icon: ImageVector,
    isActive: Boolean,
    activeColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = if (isActive) activeColor.copy(alpha = 0.2f) else EchoelColors.bgElevated,
        border = if (isActive)
            BorderStroke(1.dp, activeColor.copy(alpha = 0.5f))
        else null
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                icon,
                contentDescription = label,
                tint = if (isActive) activeColor else EchoelColors.textTertiary,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = if (isActive) activeColor else EchoelColors.textTertiary
            )
        }
    }
}

// ================================================================
// Binaural Beats Screen
// ================================================================

/**
 * Binaural Beats Screen
 * Controls for brainwave entrainment via binaural beat generation.
 * Includes brainwave state picker, carrier/beat frequency controls,
 * and a visual coherence ring.
 *
 * NOTE: Audio exploration tool, NOT a therapeutic device.
 */
@Composable
fun BinauralBeatsScreen(viewModel: EchoelmusicViewModel) {
    val enabled by viewModel.binauralBeatsEnabled.collectAsState()
    val selectedState by viewModel.selectedBrainwaveState.collectAsState()
    val binauralVolume by viewModel.binauralVolume.collectAsState()
    val carrierFreq by viewModel.carrierFrequency.collectAsState()
    val beatFreq by viewModel.beatFrequency.collectAsState()
    val coherence by viewModel.coherence.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        // Header with coherence ring
        item {
            BinauralHeaderCard(
                enabled = enabled,
                coherence = coherence,
                selectedState = selectedState,
                onToggle = { viewModel.toggleBinauralBeats() }
            )
        }

        // Brainwave State Picker
        item {
            BrainwaveStatePicker(
                selectedState = selectedState,
                onStateSelected = { viewModel.selectBrainwaveState(it) }
            )
        }

        // Frequency Controls
        item {
            FrequencyControlsCard(
                viewModel = viewModel,
                carrierFreq = carrierFreq,
                beatFreq = beatFreq,
                binauralVolume = binauralVolume
            )
        }

        // Info card
        item {
            BrainwaveInfoCard(selectedState = selectedState)
        }

        // Disclaimer
        item {
            Text(
                "Audio exploration tool for personal use. " +
                        "Not a medical device. Not intended to diagnose, treat, or prevent any condition.",
                style = MaterialTheme.typography.labelSmall,
                color = EchoelColors.textTertiary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            )
        }

        item {
            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

/**
 * Binaural beats header with animated coherence ring visualization.
 */
@Composable
fun BinauralHeaderCard(
    enabled: Boolean,
    coherence: Float,
    selectedState: BrainwaveState,
    onToggle: () -> Unit
) {
    val stateColor = brainwaveColor(selectedState)

    val infiniteTransition = rememberInfiniteTransition(label = "ring")
    val ringRotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = if (enabled) 4000 else 10000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Coherence ring
            Box(
                modifier = Modifier.size(160.dp),
                contentAlignment = Alignment.Center
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val ringSize = size.minDimension
                    val strokeWidth = 6f
                    val radius = (ringSize - strokeWidth) / 2f
                    val center = Offset(size.width / 2f, size.height / 2f)

                    // Background ring
                    drawCircle(
                        color = EchoelColors.bgElevated,
                        radius = radius,
                        center = center,
                        style = Stroke(width = strokeWidth)
                    )

                    // Animated segments
                    val segmentCount = 12
                    for (i in 0 until segmentCount) {
                        val segmentAngle = (360f / segmentCount) * i + ringRotation
                        val radians = segmentAngle * PI.toFloat() / 180f
                        val segAlpha = if (i.toFloat() / segmentCount < coherence) 0.8f else 0.1f

                        val dotRadius = 4f
                        val dotX = center.x + radius * cos(radians)
                        val dotY = center.y + radius * sin(radians)

                        drawCircle(
                            color = stateColor.copy(alpha = segAlpha),
                            radius = dotRadius,
                            center = Offset(dotX, dotY)
                        )
                    }
                }

                // Center text
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "${selectedState.binauralBeatHz}",
                        style = MaterialTheme.typography.displayMedium,
                        color = stateColor,
                        fontWeight = FontWeight.Light
                    )
                    Text(
                        "Hz",
                        style = MaterialTheme.typography.labelLarge,
                        color = EchoelColors.textTertiary
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                selectedState.displayName,
                style = MaterialTheme.typography.headlineSmall,
                color = stateColor,
                fontWeight = FontWeight.Bold
            )
            Text(
                selectedState.description,
                style = MaterialTheme.typography.bodyMedium,
                color = EchoelColors.textSecondary
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Enable/disable toggle
            Button(
                onClick = onToggle,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (enabled) stateColor else EchoelColors.bgElevated,
                    contentColor = if (enabled) EchoelColors.deepBlack else EchoelColors.textSecondary
                ),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(0.6f)
            ) {
                Icon(
                    if (enabled) Icons.Default.Stop else Icons.Default.PlayArrow,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    if (enabled) "Stop Binaural" else "Start Binaural",
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

/**
 * Horizontal brainwave state picker with colored chips.
 */
@Composable
fun BrainwaveStatePicker(
    selectedState: BrainwaveState,
    onStateSelected: (BrainwaveState) -> Unit
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Brainwave State",
                style = MaterialTheme.typography.titleMedium,
                color = EchoelColors.neonCyan
            )
            Spacer(modifier = Modifier.height(12.dp))

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(BrainwaveState.entries.toList()) { state ->
                    val isSelected = state == selectedState
                    val color = brainwaveColor(state)

                    Surface(
                        modifier = Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .clickable { onStateSelected(state) },
                        shape = RoundedCornerShape(14.dp),
                        color = if (isSelected) color.copy(alpha = 0.2f) else EchoelColors.bgElevated,
                        border = if (isSelected)
                            BorderStroke(2.dp, color)
                        else
                            BorderStroke(1.dp, EchoelColors.bgElevated)
                    ) {
                        Column(
                            modifier = Modifier
                                .width(90.dp)
                                .padding(12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(12.dp)
                                    .clip(CircleShape)
                                    .background(color)
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                state.displayName,
                                style = MaterialTheme.typography.labelLarge,
                                color = if (isSelected) color else EchoelColors.textSecondary,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                            )
                            Text(
                                state.frequencyRange,
                                style = MaterialTheme.typography.labelSmall,
                                color = EchoelColors.textTertiary,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Frequency and volume controls for binaural beats.
 */
@Composable
fun FrequencyControlsCard(
    viewModel: EchoelmusicViewModel,
    carrierFreq: Float,
    beatFreq: Float,
    binauralVolume: Float
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Frequency Controls",
                style = MaterialTheme.typography.titleMedium,
                color = EchoelColors.neonPurple
            )
            Spacer(modifier = Modifier.height(12.dp))

            // Carrier Frequency
            Text(
                "Carrier: ${carrierFreq.toInt()} Hz",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textSecondary
            )
            Slider(
                value = carrierFreq,
                onValueChange = { viewModel.setCarrierFrequency(it) },
                valueRange = 50f..800f,
                colors = SliderDefaults.colors(
                    thumbColor = EchoelColors.neonCyan,
                    activeTrackColor = EchoelColors.neonCyan,
                    inactiveTrackColor = EchoelColors.bgElevated
                )
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Beat Frequency
            Text(
                "Beat: ${String.format("%.1f", beatFreq)} Hz",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textSecondary
            )
            Slider(
                value = beatFreq,
                onValueChange = { viewModel.setBeatFrequency(it) },
                valueRange = 0.5f..100f,
                colors = SliderDefaults.colors(
                    thumbColor = EchoelColors.neonPurple,
                    activeTrackColor = EchoelColors.neonPurple,
                    inactiveTrackColor = EchoelColors.bgElevated
                )
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Volume
            Text(
                "Volume: ${(binauralVolume * 100).toInt()}%",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textSecondary
            )
            Slider(
                value = binauralVolume,
                onValueChange = { viewModel.setBinauralVolume(it) },
                valueRange = 0f..1f,
                colors = SliderDefaults.colors(
                    thumbColor = EchoelColors.neonPink,
                    activeTrackColor = EchoelColors.neonPink,
                    inactiveTrackColor = EchoelColors.bgElevated
                )
            )

            // Left/Right ear info
            Spacer(modifier = Modifier.height(8.dp))
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = EchoelColors.bgElevated
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "Left Ear",
                            style = MaterialTheme.typography.labelSmall,
                            color = EchoelColors.textTertiary
                        )
                        Text(
                            "${carrierFreq.toInt()} Hz",
                            style = MaterialTheme.typography.bodyMedium,
                            color = EchoelColors.neonCyan,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "Difference",
                            style = MaterialTheme.typography.labelSmall,
                            color = EchoelColors.textTertiary
                        )
                        Text(
                            "${String.format("%.1f", beatFreq)} Hz",
                            style = MaterialTheme.typography.bodyMedium,
                            color = EchoelColors.neonPurple,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "Right Ear",
                            style = MaterialTheme.typography.labelSmall,
                            color = EchoelColors.textTertiary
                        )
                        Text(
                            "${(carrierFreq + beatFreq).toInt()} Hz",
                            style = MaterialTheme.typography.bodyMedium,
                            color = EchoelColors.neonPink,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

/**
 * Info card about the selected brainwave state.
 */
@Composable
fun BrainwaveInfoCard(selectedState: BrainwaveState) {
    val color = brainwaveColor(selectedState)

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = color.copy(alpha = 0.08f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Info,
                    contentDescription = null,
                    tint = color,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    "About ${selectedState.displayName} Waves",
                    style = MaterialTheme.typography.titleSmall,
                    color = color
                )
            }
            Spacer(modifier = Modifier.height(8.dp))

            val description = when (selectedState) {
                BrainwaveState.DELTA ->
                    "Delta waves (0.5-4 Hz) are associated with deep, dreamless sleep and physical recovery. " +
                            "The binaural beat creates a gentle pulsation at this frequency range."
                BrainwaveState.THETA ->
                    "Theta waves (4-8 Hz) are associated with deep meditation, creativity, and the hypnagogic state " +
                            "between waking and sleeping. Often used for creative visualization."
                BrainwaveState.ALPHA ->
                    "Alpha waves (8-13 Hz) are associated with relaxed awareness and calm focus. " +
                            "This is a balanced state often experienced during light meditation."
                BrainwaveState.BETA ->
                    "Beta waves (13-30 Hz) are associated with active thinking, concentration, and problem-solving. " +
                            "Useful for focused work sessions and study."
                BrainwaveState.GAMMA ->
                    "Gamma waves (30-100 Hz) are associated with heightened perception, peak cognitive performance, " +
                            "and moments of insight. The fastest brainwave frequency."
            }

            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = EchoelColors.textSecondary
            )
        }
    }
}

// ================================================================
// Synth Screen (Enhanced)
// ================================================================

/**
 * Synth Screen - Polyphonic synthesizer with filter, oscillator, and keyboard.
 */
@Composable
fun SynthScreen(viewModel: EchoelmusicViewModel) {
    var filterCutoff by remember { mutableFloatStateOf(5000f) }
    var filterRes by remember { mutableFloatStateOf(0.3f) }
    var oscMix by remember { mutableFloatStateOf(0.5f) }
    var attackTime by remember { mutableFloatStateOf(0.01f) }
    var releaseTime by remember { mutableFloatStateOf(0.3f) }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        item {
            Text(
                "Polyphonic Synthesizer",
                style = MaterialTheme.typography.headlineMedium,
                color = EchoelColors.neonCyan
            )
        }

        // Filter section
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "Filter",
                        style = MaterialTheme.typography.titleMedium,
                        color = EchoelColors.neonPurple
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        "Cutoff: ${filterCutoff.toInt()} Hz",
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textSecondary
                    )
                    Slider(
                        value = filterCutoff,
                        onValueChange = {
                            filterCutoff = it
                            viewModel.audioEngine.setParameter(
                                AudioEngine.Params.FILTER_CUTOFF, it
                            )
                        },
                        valueRange = 20f..20000f,
                        colors = SliderDefaults.colors(
                            thumbColor = EchoelColors.neonPurple,
                            activeTrackColor = EchoelColors.neonPurple,
                            inactiveTrackColor = EchoelColors.bgElevated
                        )
                    )

                    Text(
                        "Resonance: ${(filterRes * 100).toInt()}%",
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textSecondary
                    )
                    Slider(
                        value = filterRes,
                        onValueChange = {
                            filterRes = it
                            viewModel.audioEngine.setParameter(
                                AudioEngine.Params.FILTER_RESONANCE, it
                            )
                        },
                        valueRange = 0f..1f,
                        colors = SliderDefaults.colors(
                            thumbColor = EchoelColors.neonPurple,
                            activeTrackColor = EchoelColors.neonPurple,
                            inactiveTrackColor = EchoelColors.bgElevated
                        )
                    )
                }
            }
        }

        // Oscillator section
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "Oscillators",
                        style = MaterialTheme.typography.titleMedium,
                        color = EchoelColors.neonCyan
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        "Osc Mix: ${(oscMix * 100).toInt()}%",
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textSecondary
                    )
                    Slider(
                        value = oscMix,
                        onValueChange = {
                            oscMix = it
                            viewModel.audioEngine.setParameter(
                                AudioEngine.Params.OSC2_MIX, it
                            )
                        },
                        valueRange = 0f..1f,
                        colors = SliderDefaults.colors(
                            thumbColor = EchoelColors.neonCyan,
                            activeTrackColor = EchoelColors.neonCyan,
                            inactiveTrackColor = EchoelColors.bgElevated
                        )
                    )
                }
            }
        }

        // Envelope section
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "Envelope",
                        style = MaterialTheme.typography.titleMedium,
                        color = EchoelColors.neonPink
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        "Attack: ${String.format("%.0f", attackTime * 1000)} ms",
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textSecondary
                    )
                    Slider(
                        value = attackTime,
                        onValueChange = {
                            attackTime = it
                            viewModel.audioEngine.setParameter(
                                AudioEngine.Params.AMP_ATTACK, it
                            )
                        },
                        valueRange = 0.001f..2f,
                        colors = SliderDefaults.colors(
                            thumbColor = EchoelColors.neonPink,
                            activeTrackColor = EchoelColors.neonPink,
                            inactiveTrackColor = EchoelColors.bgElevated
                        )
                    )

                    Text(
                        "Release: ${String.format("%.0f", releaseTime * 1000)} ms",
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textSecondary
                    )
                    Slider(
                        value = releaseTime,
                        onValueChange = {
                            releaseTime = it
                            viewModel.audioEngine.setParameter(
                                AudioEngine.Params.AMP_RELEASE, it
                            )
                        },
                        valueRange = 0.01f..5f,
                        colors = SliderDefaults.colors(
                            thumbColor = EchoelColors.neonPink,
                            activeTrackColor = EchoelColors.neonPink,
                            inactiveTrackColor = EchoelColors.bgElevated
                        )
                    )
                }
            }
        }

        // Keyboard
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "Keyboard",
                        style = MaterialTheme.typography.titleMedium,
                        color = EchoelColors.textSecondary
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    val noteNames = listOf("C", "D", "E", "F", "G", "A", "B", "C")
                    val notes = listOf(60, 62, 64, 65, 67, 69, 71, 72)

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        notes.forEachIndexed { index, note ->
                            Button(
                                onClick = { viewModel.noteOn(note, 100) },
                                modifier = Modifier
                                    .weight(1f)
                                    .height(56.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = EchoelColors.bgElevated,
                                    contentColor = EchoelColors.neonCyan
                                ),
                                shape = RoundedCornerShape(8.dp),
                                contentPadding = PaddingValues(0.dp)
                            ) {
                                Text(
                                    noteNames[index],
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

// ================================================================
// Bio-Reactive Screen (Enhanced)
// ================================================================

/**
 * Bio-Reactive Screen
 * Displays Health Connect data with visual indicators and bio-audio mapping info.
 */
@Composable
fun BioReactiveScreen(viewModel: EchoelmusicViewModel) {
    val heartRate by viewModel.heartRate.collectAsState()
    val hrv by viewModel.hrv.collectAsState()
    val coherence by viewModel.coherence.collectAsState()
    val isConnected by viewModel.bioReactiveEngine.isConnected.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        item {
            Text(
                "Bio-Reactive Control",
                style = MaterialTheme.typography.headlineMedium,
                color = EchoelColors.neonPink
            )
        }

        // Connection status
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (isConnected)
                        EchoelColors.neonCyan.copy(alpha = 0.1f)
                    else
                        EchoelColors.sunset.copy(alpha = 0.1f)
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        if (isConnected) Icons.Default.CheckCircle else Icons.Default.Warning,
                        contentDescription = null,
                        tint = if (isConnected) EchoelColors.neonCyan else EchoelColors.sunset
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            if (isConnected) "Health Connect Active" else "Health Connect Unavailable",
                            style = MaterialTheme.typography.bodyMedium,
                            color = EchoelColors.textPrimary
                        )
                        Text(
                            if (isConnected) "Receiving live bio data"
                            else "Using simulated data for demo",
                            style = MaterialTheme.typography.labelSmall,
                            color = EchoelColors.textTertiary
                        )
                    }
                }
            }
        }

        // Bio metrics
        item {
            BioMetricsRow(
                heartRate = heartRate,
                hrv = hrv,
                coherence = coherence
            )
        }

        // Coherence visualization
        item {
            CoherenceVisualizationCard(coherence = coherence)
        }

        // Bio-Audio Mapping
        item {
            BioAudioMappingCard(coherence = coherence)
        }

        item {
            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

/**
 * Visual representation of coherence level with animated ring.
 */
@Composable
fun CoherenceVisualizationCard(coherence: Float) {
    val coherenceColor by animateColorAsState(
        targetValue = when {
            coherence > 0.8f -> EchoelColors.coherenceHigh
            coherence > 0.5f -> EchoelColors.coherenceMedium
            else -> EchoelColors.coherenceLow
        },
        animationSpec = tween(durationMillis = 1000),
        label = "cohColor"
    )

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                "Coherence Level",
                style = MaterialTheme.typography.titleMedium,
                color = coherenceColor
            )
            Spacer(modifier = Modifier.height(16.dp))

            Box(
                modifier = Modifier.size(140.dp),
                contentAlignment = Alignment.Center
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val strokeWidth = 10f
                    val radius = (size.minDimension - strokeWidth) / 2f
                    val center = Offset(size.width / 2f, size.height / 2f)

                    // Background arc
                    drawArc(
                        color = EchoelColors.bgElevated,
                        startAngle = -225f,
                        sweepAngle = 270f,
                        useCenter = false,
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                    )

                    // Coherence arc
                    drawArc(
                        color = coherenceColor,
                        startAngle = -225f,
                        sweepAngle = 270f * coherence,
                        useCenter = false,
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                    )
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "${(coherence * 100).toInt()}%",
                        style = MaterialTheme.typography.headlineLarge,
                        color = coherenceColor,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        when {
                            coherence > 0.8f -> "High"
                            coherence > 0.5f -> "Medium"
                            else -> "Low"
                        },
                        style = MaterialTheme.typography.labelMedium,
                        color = EchoelColors.textTertiary
                    )
                }
            }
        }
    }
}

// ================================================================
// Settings Screen (Enhanced)
// ================================================================

/**
 * Settings Screen with audio, MIDI, and bio-reactive configuration.
 */
@Composable
fun SettingsScreen(viewModel: EchoelmusicViewModel) {
    val isPlaying by viewModel.isPlaying.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(vertical = 16.dp)
    ) {
        item {
            Text(
                "Settings",
                style = MaterialTheme.typography.headlineMedium,
                color = EchoelColors.neonCyan
            )
        }

        // Audio settings
        item {
            SettingsSectionCard(
                title = "Audio Engine",
                titleColor = EchoelColors.neonCyan,
                items = listOf(
                    SettingsItem("Buffer Size", "192 frames (~4ms)", Icons.Default.Speed),
                    SettingsItem("Sample Rate", "48000 Hz", Icons.Default.GraphicEq),
                    SettingsItem("Status", if (isPlaying) "Running" else "Idle", Icons.Default.PlayCircle)
                )
            )
        }

        // MIDI settings
        item {
            SettingsSectionCard(
                title = "MIDI",
                titleColor = EchoelColors.neonPurple,
                items = listOf(
                    SettingsItem("USB MIDI", "Auto-connect enabled", Icons.Default.Usb),
                    SettingsItem("Bluetooth MIDI", "Scan for devices", Icons.Default.Bluetooth),
                    SettingsItem("MPE", "Enabled (zones 2-16)", Icons.Default.Tune)
                )
            )
        }

        // Bio-Reactive settings
        item {
            SettingsSectionCard(
                title = "Bio-Reactive",
                titleColor = EchoelColors.neonPink,
                items = listOf(
                    SettingsItem("Health Connect", "Manage permissions", Icons.Default.Favorite),
                    SettingsItem("Update Rate", "10 Hz", Icons.Default.Timer),
                    SettingsItem("Coherence Window", "60 samples", Icons.Default.Waves)
                )
            )
        }

        // About
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "Echoelmusic",
                        style = MaterialTheme.typography.titleLarge,
                        color = EchoelColors.neonCyan,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Bio-Reactive Audio-Visual Platform",
                        style = MaterialTheme.typography.bodySmall,
                        color = EchoelColors.textTertiary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "Version 1.2.0",
                        style = MaterialTheme.typography.labelSmall,
                        color = EchoelColors.textTertiary
                    )
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

data class SettingsItem(
    val title: String,
    val subtitle: String,
    val icon: ImageVector
)

@Composable
fun SettingsSectionCard(
    title: String,
    titleColor: Color,
    items: List<SettingsItem>
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = EchoelColors.bgSurface.copy(alpha = 0.7f)
        )
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                color = titleColor
            )
            Spacer(modifier = Modifier.height(8.dp))

            items.forEachIndexed { index, item ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        item.icon,
                        contentDescription = null,
                        tint = titleColor.copy(alpha = 0.7f),
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            item.title,
                            style = MaterialTheme.typography.bodyMedium,
                            color = EchoelColors.textPrimary
                        )
                        Text(
                            item.subtitle,
                            style = MaterialTheme.typography.labelSmall,
                            color = EchoelColors.textTertiary
                        )
                    }
                    Icon(
                        Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = EchoelColors.textTertiary,
                        modifier = Modifier.size(18.dp)
                    )
                }
                if (index < items.size - 1) {
                    HorizontalDivider(
                        color = EchoelColors.bgElevated,
                        thickness = 1.dp,
                        modifier = Modifier.padding(start = 32.dp)
                    )
                }
            }
        }
    }
}

// ================================================================
// Utility Functions
// ================================================================

/**
 * Returns the theme color associated with a brainwave state.
 */
fun brainwaveColor(state: BrainwaveState): Color {
    return when (state) {
        BrainwaveState.DELTA -> EchoelColors.brainwaveDelta
        BrainwaveState.THETA -> EchoelColors.brainwaveTheta
        BrainwaveState.ALPHA -> EchoelColors.brainwaveAlpha
        BrainwaveState.BETA -> EchoelColors.brainwaveBeta
        BrainwaveState.GAMMA -> EchoelColors.brainwaveGamma
    }
}
