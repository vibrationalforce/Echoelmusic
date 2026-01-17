/**
 * Theme.kt
 * Echoelmusic Wear OS Theme
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.wear.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme

// Echoelmusic Brand Colors
val EchoelPrimary = Color(0xFF6366F1)      // Indigo
val EchoelSecondary = Color(0xFF8B5CF6)     // Purple
val EchoelSurface = Color(0xFF1E1E2E)       // Dark surface
val EchoelBackground = Color(0xFF0F0F1A)    // Dark background

val CoherenceHigh = Color(0xFF4CAF50)       // Green
val CoherenceMedium = Color(0xFFFFC107)     // Yellow
val CoherenceLow = Color(0xFFFF5722)        // Orange

val WearColors = Colors(
    primary = EchoelPrimary,
    primaryVariant = EchoelSecondary,
    secondary = EchoelSecondary,
    secondaryVariant = EchoelSecondary,
    background = EchoelBackground,
    surface = EchoelSurface,
    error = Color(0xFFCF6679),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onBackground = Color.White,
    onSurface = Color.White,
    onSurfaceVariant = Color.Gray,
    onError = Color.Black
)

@Composable
fun EchoelmusicWearTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colors = WearColors,
        content = content
    )
}
