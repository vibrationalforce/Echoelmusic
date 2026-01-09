/**
 * QuantumVisualizationView.kt
 * Echoelmusic - Android Quantum Visualization Composables
 *
 * GPU-accelerated quantum visualizations using Jetpack Compose Canvas
 * 300% Power Mode - Tauchfliegen Edition
 *
 * Created: 2026-01-05
 */

package com.echoelmusic.quantum.ui

import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.echoelmusic.quantum.*
import kotlin.math.*

// MARK: - Main Visualization Screen

@RequiresApi(Build.VERSION_CODES.O)
@Composable
fun QuantumVisualizationScreen(
    emulator: QuantumLightEmulator,
    modifier: Modifier = Modifier
) {
    val coherence by emulator.coherenceLevel.collectAsState()
    val mode by emulator.emulationMode.collectAsState()
    val lightField by emulator.lightField.collectAsState()
    val isRunning by emulator.isRunning.collectAsState()

    var selectedVisualization by remember { mutableStateOf(VisualizationType.COHERENCE_FIELD) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A1A))
    ) {
        // Top Bar
        QuantumTopBar(
            coherence = coherence,
            mode = mode,
            isRunning = isRunning,
            onToggle = { if (isRunning) emulator.stop() else emulator.start() }
        )

        // Visualization Canvas
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
        ) {
            QuantumCanvas(
                visualizationType = selectedVisualization,
                coherence = coherence,
                lightField = lightField,
                modifier = Modifier.fillMaxSize()
            )
        }

        // Visualization Selector
        VisualizationSelector(
            selected = selectedVisualization,
            onSelect = { selectedVisualization = it }
        )

        // Mode Selector
        ModeSelector(
            currentMode = mode,
            onModeChange = { emulator.setMode(it) }
        )
    }
}

// MARK: - Top Bar

@Composable
fun QuantumTopBar(
    coherence: Float,
    mode: EmulationMode,
    isRunning: Boolean,
    onToggle: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFF1A1A2E),
        tonalElevation = 4.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Coherence Indicator
            CoherenceGauge(coherence = coherence)

            // Mode Label
            Text(
                text = mode.name.replace("_", " "),
                style = MaterialTheme.typography.titleMedium,
                color = Color.Cyan
            )

            // Play/Pause Button
            FilledIconButton(
                onClick = onToggle,
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = if (isRunning) Color.Green.copy(alpha = 0.3f) else Color.Purple.copy(alpha = 0.3f)
                )
            ) {
                Text(if (isRunning) "⏸" else "▶")
            }
        }
    }
}

// MARK: - Coherence Gauge

@Composable
fun CoherenceGauge(coherence: Float) {
    val animatedCoherence by animateFloatAsState(
        targetValue = coherence,
        animationSpec = spring(dampingRatio = 0.7f)
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.size(60.dp)
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            // Background ring
            drawArc(
                color = Color.Gray.copy(alpha = 0.3f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                style = Stroke(width = 6.dp.toPx(), cap = StrokeCap.Round)
            )

            // Coherence ring
            val coherenceColor = when {
                animatedCoherence > 0.7f -> Color.Green
                animatedCoherence > 0.4f -> Color.Yellow
                else -> Color(0xFFFF6B00)
            }

            drawArc(
                color = coherenceColor,
                startAngle = -90f,
                sweepAngle = animatedCoherence * 360f,
                useCenter = false,
                style = Stroke(width = 6.dp.toPx(), cap = StrokeCap.Round)
            )
        }

        Text(
            text = "${(coherence * 100).toInt()}",
            style = MaterialTheme.typography.titleMedium,
            color = Color.White
        )
    }
}

// MARK: - Quantum Canvas

@Composable
fun QuantumCanvas(
    visualizationType: VisualizationType,
    coherence: Float,
    lightField: LightField?,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition()
    val time by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 2 * PI.toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(10000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        )
    )

    Canvas(modifier = modifier) {
        val center = Offset(size.width / 2, size.height / 2)
        val minDim = minOf(size.width, size.height)

        when (visualizationType) {
            VisualizationType.INTERFERENCE_PATTERN ->
                drawInterferencePattern(center, minDim, coherence, time)
            VisualizationType.WAVE_FUNCTION ->
                drawWaveFunction(center, minDim, coherence, time)
            VisualizationType.COHERENCE_FIELD ->
                drawCoherenceField(size, coherence, time)
            VisualizationType.PHOTON_FLOW ->
                drawPhotonFlow(size, coherence, time, lightField)
            VisualizationType.SACRED_GEOMETRY ->
                drawSacredGeometry(center, minDim, coherence, time)
            VisualizationType.QUANTUM_TUNNEL ->
                drawQuantumTunnel(center, minDim, coherence, time)
            VisualizationType.BIOPHOTON_AURA ->
                drawBiophotonAura(center, minDim, coherence, time)
            VisualizationType.LIGHT_MANDALA ->
                drawLightMandala(center, minDim, coherence, time)
            VisualizationType.HOLOGRAPHIC_DISPLAY ->
                drawHolographicDisplay(size, coherence, time)
            VisualizationType.COSMIC_WEB ->
                drawCosmicWeb(size, coherence, time)
        }
    }
}

// MARK: - Visualization Renderers

private fun DrawScope.drawInterferencePattern(
    center: Offset,
    size: Float,
    coherence: Float,
    time: Float
) {
    val waveCount = (20 + coherence * 30).toInt()

    for (i in 0 until waveCount) {
        val yOffset = (i.toFloat() / waveCount) * this.size.height
        val path = Path()

        path.moveTo(0f, yOffset)

        for (x in 0 until this.size.width.toInt() step 5) {
            val wave1 = sin(x * 0.02f + time) * 20 * coherence
            val wave2 = sin(x * 0.03f - time + i * 0.2f) * 15 * coherence
            val y = yOffset + wave1 + wave2

            path.lineTo(x.toFloat(), y)
        }

        drawPath(
            path = path,
            color = Color.Cyan.copy(alpha = 0.3f + coherence * 0.3f),
            style = Stroke(width = 1.5f)
        )
    }
}

private fun DrawScope.drawWaveFunction(
    center: Offset,
    size: Float,
    coherence: Float,
    time: Float
) {
    val rings = (10 + coherence * 20).toInt()

    for (i in 0 until rings) {
        val progress = i.toFloat() / rings
        val radius = progress * size * 0.45f
        val pulse = sin(time * 2 + progress * PI.toFloat() * 4) * 10

        drawCircle(
            color = Color.Cyan.copy(alpha = (1 - progress) * 0.5f),
            radius = radius + pulse * coherence,
            center = center,
            style = Stroke(width = 2f + coherence * 3)
        )
    }
}

private fun DrawScope.drawCoherenceField(
    canvasSize: Size,
    coherence: Float,
    time: Float
) {
    val gridSize = 15
    val cellWidth = canvasSize.width / gridSize
    val cellHeight = canvasSize.height / gridSize

    for (row in 0 until gridSize) {
        for (col in 0 until gridSize) {
            val x = col * cellWidth
            val y = row * cellHeight

            val noise = sin((row + col).toFloat() * coherence * 0.5f + time)
            val brightness = (0.2f + abs(noise) * 0.6f) * coherence

            drawRect(
                color = Color(0xFF6B00FF).copy(alpha = brightness),
                topLeft = Offset(x + 2, y + 2),
                size = Size(cellWidth - 4, cellHeight - 4)
            )
        }
    }
}

private fun DrawScope.drawPhotonFlow(
    canvasSize: Size,
    coherence: Float,
    time: Float,
    lightField: LightField?
) {
    val photonCount = (50 + coherence * 100).toInt()

    for (i in 0 until photonCount) {
        val progress = (i.toFloat() / photonCount + time / (2 * PI.toFloat())) % 1f
        val x = progress * canvasSize.width
        val y = canvasSize.height / 2 + sin(progress * PI.toFloat() * 4 + time) * 100 * coherence

        val photonSize = 4f + coherence * 8f

        drawCircle(
            color = Color.White.copy(alpha = 0.6f + coherence * 0.4f),
            radius = photonSize,
            center = Offset(x, y)
        )
    }
}

private fun DrawScope.drawSacredGeometry(
    center: Offset,
    size: Float,
    coherence: Float,
    time: Float
) {
    val petals = 6
    val layers = (3 + coherence * 4).toInt()
    val baseRadius = size * 0.15f

    for (layer in 0 until layers) {
        val layerRadius = baseRadius * (layer + 1)
        val rotation = time * (layer + 1) * 0.1f

        for (petal in 0 until petals) {
            val angle = petal * PI.toFloat() * 2 / petals + rotation
            val petalCenter = Offset(
                center.x + cos(angle) * layerRadius,
                center.y + sin(angle) * layerRadius
            )

            drawCircle(
                color = Color.Yellow.copy(alpha = 0.4f * coherence),
                radius = layerRadius,
                center = petalCenter,
                style = Stroke(width = 1.5f)
            )
        }
    }
}

private fun DrawScope.drawQuantumTunnel(
    center: Offset,
    size: Float,
    coherence: Float,
    time: Float
) {
    val rings = 30

    for (i in 0 until rings) {
        val progress = i.toFloat() / rings
        val radius = 50 + progress * size * 0.4f * (1 + coherence)
        val opacity = (1 - progress) * coherence
        val hue = (progress * 0.3f + time / (2 * PI.toFloat()) * 0.5f) % 1f

        drawOval(
            color = Color.hsv(hue * 360, 0.8f, 0.9f).copy(alpha = opacity),
            topLeft = Offset(center.x - radius, center.y - radius * 0.5f),
            size = Size(radius * 2, radius),
            style = Stroke(width = 2f)
        )
    }
}

private fun DrawScope.drawBiophotonAura(
    center: Offset,
    size: Float,
    coherence: Float,
    time: Float
) {
    val colors = listOf(
        Color.Red, Color(0xFFFF6B00), Color.Yellow,
        Color.Green, Color.Cyan, Color.Blue, Color(0xFF8B00FF)
    )

    colors.forEachIndexed { index, color ->
        val baseRadius = 100f + index * 50f
        val radius = baseRadius * (0.8f + coherence * 0.4f)
        val segments = 60

        val path = Path()

        for (s in 0..segments) {
            val angle = s * 2 * PI.toFloat() / segments
            val noise = sin(angle * 6 + time) * 20 * coherence
            val r = radius + noise
            val point = Offset(
                center.x + cos(angle) * r,
                center.y + sin(angle) * r
            )

            if (s == 0) path.moveTo(point.x, point.y)
            else path.lineTo(point.x, point.y)
        }
        path.close()

        drawPath(
            path = path,
            color = color.copy(alpha = 0.15f),
            style = Fill
        )
        drawPath(
            path = path,
            color = color.copy(alpha = 0.5f),
            style = Stroke(width = 2f)
        )
    }
}

private fun DrawScope.drawLightMandala(
    center: Offset,
    size: Float,
    coherence: Float,
    time: Float
) {
    val arms = (6 + coherence * 12).toInt()
    val rings = 5

    for (ring in 0 until rings) {
        val ringRadius = (ring + 1) * size * 0.08f

        for (arm in 0 until arms) {
            val angle = arm * 2 * PI.toFloat() / arms + time * 0.5f
            val endPoint = Offset(
                center.x + cos(angle) * ringRadius,
                center.y + sin(angle) * ringRadius
            )

            val hue = arm.toFloat() / arms

            drawLine(
                color = Color.hsv(hue * 360, 0.7f, 0.9f).copy(alpha = 0.6f),
                start = center,
                end = endPoint,
                strokeWidth = 2f
            )
        }
    }
}

private fun DrawScope.drawHolographicDisplay(
    canvasSize: Size,
    coherence: Float,
    time: Float
) {
    val lineCount = (30 + coherence * 50).toInt()

    for (i in 0 until lineCount) {
        val progress = i.toFloat() / lineCount
        val x = progress * canvasSize.width
        val hue = progress * 0.3f

        val path = Path()
        path.moveTo(x, 0f)

        for (y in 0 until canvasSize.height.toInt() step 5) {
            val wave = sin(y * 0.02f + progress * PI.toFloat() * 2 + time) * 20 * coherence
            path.lineTo(x + wave, y.toFloat())
        }

        drawPath(
            path = path,
            color = Color.hsv(hue * 360, 0.6f, 0.8f).copy(alpha = 0.4f),
            style = Stroke(width = 1f)
        )
    }
}

private fun DrawScope.drawCosmicWeb(
    canvasSize: Size,
    coherence: Float,
    time: Float
) {
    val nodeCount = (20 + coherence * 30).toInt()
    val nodes = mutableListOf<Offset>()

    // Generate nodes
    for (i in 0 until nodeCount) {
        val angle = i * 2.399f // Golden angle
        val radius = sqrt(i.toFloat()) * 30
        nodes.add(Offset(
            canvasSize.width / 2 + cos(angle + time * 0.1f) * radius,
            canvasSize.height / 2 + sin(angle + time * 0.1f) * radius
        ))
    }

    // Draw connections
    for (i in nodes.indices) {
        for (j in (i + 1) until nodes.size) {
            val dist = (nodes[i] - nodes[j]).getDistance()
            val maxDist = 150 * (1 + coherence)

            if (dist < maxDist) {
                val opacity = (1 - dist / maxDist) * 0.5f
                drawLine(
                    color = Color.Cyan.copy(alpha = opacity),
                    start = nodes[i],
                    end = nodes[j],
                    strokeWidth = 1f
                )
            }
        }
    }

    // Draw nodes
    nodes.forEach { node ->
        drawCircle(
            color = Color.White.copy(alpha = 0.8f),
            radius = 4f,
            center = node
        )
    }
}

// MARK: - Visualization Selector

@Composable
fun VisualizationSelector(
    selected: VisualizationType,
    onSelect: (VisualizationType) -> Unit
) {
    val visualizations = VisualizationType.values()

    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(visualizations.size) { index ->
            val viz = visualizations[index]
            val isSelected = viz == selected

            FilterChip(
                selected = isSelected,
                onClick = { onSelect(viz) },
                label = {
                    Text(
                        text = viz.name.replace("_", " "),
                        style = MaterialTheme.typography.labelSmall
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = Color.Cyan.copy(alpha = 0.3f)
                )
            )
        }
    }
}

@Composable
fun LazyRow(
    modifier: Modifier = Modifier,
    horizontalArrangement: Arrangement.Horizontal = Arrangement.Start,
    content: @Composable () -> Unit
) {
    Row(
        modifier = modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = horizontalArrangement
    ) {
        content()
    }
}

@Composable
fun rememberScrollState() = remember { androidx.compose.foundation.ScrollState(0) }

@Composable
fun Modifier.horizontalScroll(state: androidx.compose.foundation.ScrollState) =
    this.then(androidx.compose.foundation.horizontalScroll(state))

// MARK: - Mode Selector

@Composable
fun ModeSelector(
    currentMode: EmulationMode,
    onModeChange: (EmulationMode) -> Unit
) {
    val modes = EmulationMode.values()

    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color(0xFF1A1A2E)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            modes.forEach { mode ->
                val isSelected = mode == currentMode

                TextButton(
                    onClick = { onModeChange(mode) },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = if (isSelected) Color.Cyan else Color.Gray
                    )
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = modeIcon(mode),
                            style = MaterialTheme.typography.titleLarge
                        )
                        Text(
                            text = mode.name.take(3),
                            style = MaterialTheme.typography.labelSmall
                        )
                    }
                }
            }
        }
    }
}

private fun modeIcon(mode: EmulationMode): String = when (mode) {
    EmulationMode.CLASSICAL -> "📻"
    EmulationMode.QUANTUM_INSPIRED -> "⚛️"
    EmulationMode.FULL_QUANTUM -> "🌀"
    EmulationMode.HYBRID_PHOTONIC -> "💡"
    EmulationMode.BIO_COHERENT -> "🧬"
}
