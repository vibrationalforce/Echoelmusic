package com.echoelmusic.app.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat

/**
 * Echoelmusic Vaporwave Theme (2026)
 *
 * Bio-Reactive Audio-Visual Platform
 * Vaporwave-inspired dark theme matching the iOS app
 *
 * Color Palette:
 * - neonCyan: #00FFFF
 * - neonPink: #FF1493
 * - neonPurple: #9B30FF
 * - deepBlack: #0A0A1A
 * - Background gradient: dark blue to deep purple
 */

// ============================================================
// Vaporwave Primary Colors
// ============================================================
val NeonCyan = Color(0xFF00FFFF)
val NeonPink = Color(0xFFFF1493)
val NeonPurple = Color(0xFF9B30FF)
val DeepBlack = Color(0xFF0A0A1A)

// ============================================================
// Extended Vaporwave Palette
// ============================================================
val VaporwaveMagenta = Color(0xFFFF00FF)
val VaporwaveLavender = Color(0xFFB388FF)
val VaporwaveHotPink = Color(0xFFFF69B4)
val VaporwaveSunset = Color(0xFFFF6B6B)
val VaporwaveGold = Color(0xFFFFD700)
val VaporwaveMint = Color(0xFF00FFAB)

// ============================================================
// Background System (Dark Blue to Deep Purple gradient)
// ============================================================
val VaporBgDeep = Color(0xFF0A0A1A)        // Deepest background
val VaporBgDarkBlue = Color(0xFF0D0B2E)    // Dark blue layer
val VaporBgMidnight = Color(0xFF12103A)    // Midnight purple
val VaporBgSurface = Color(0xFF16133D)     // Card / panel surface
val VaporBgElevated = Color(0xFF1C1850)    // Elevated surfaces
val VaporBgDeepPurple = Color(0xFF2D1B69)  // Deep purple accent bg

// ============================================================
// Text Colors
// ============================================================
val VaporTextPrimary = Color(0xFFF0F0FF)      // Near-white with blue tint
val VaporTextSecondary = Color(0xBBE0E0FF)    // 73% opacity
val VaporTextTertiary = Color(0x77C0C0DD)     // 47% opacity

// ============================================================
// Bio-Reactive Colors
// ============================================================
val CoherenceLow = Color(0xFFFF6B6B)       // Warm red
val CoherenceMedium = Color(0xFFFFD700)    // Gold
val CoherenceHigh = Color(0xFF00FFFF)      // Neon cyan

// ============================================================
// Brainwave State Colors (for binaural beats UI)
// ============================================================
val BrainwaveDelta = Color(0xFF9B30FF)     // Deep purple - deep sleep
val BrainwaveTheta = Color(0xFF6366F1)     // Indigo - meditation
val BrainwaveAlpha = Color(0xFF00FFAB)     // Mint green - relaxation
val BrainwaveBeta = Color(0xFFFFD700)      // Gold - focus
val BrainwaveGamma = Color(0xFFFF1493)     // Neon pink - peak performance

// ============================================================
// Dark Color Scheme (Vaporwave)
// ============================================================
private val VaporwaveDarkColorScheme = darkColorScheme(
    primary = NeonCyan,
    onPrimary = DeepBlack,
    primaryContainer = NeonCyan.copy(alpha = 0.15f),
    onPrimaryContainer = NeonCyan,

    secondary = NeonPink,
    onSecondary = DeepBlack,
    secondaryContainer = NeonPink.copy(alpha = 0.15f),
    onSecondaryContainer = NeonPink,

    tertiary = NeonPurple,
    onTertiary = DeepBlack,
    tertiaryContainer = NeonPurple.copy(alpha = 0.15f),
    onTertiaryContainer = NeonPurple,

    background = VaporBgDeep,
    onBackground = VaporTextPrimary,

    surface = VaporBgSurface,
    onSurface = VaporTextPrimary,

    surfaceVariant = VaporBgElevated,
    onSurfaceVariant = VaporTextSecondary,

    error = VaporwaveSunset,
    onError = Color.White,

    outline = NeonPurple.copy(alpha = 0.3f),
    outlineVariant = NeonCyan.copy(alpha = 0.1f),

    inverseSurface = VaporTextPrimary,
    inverseOnSurface = VaporBgDeep,
    inversePrimary = Color(0xFF006666),

    surfaceTint = NeonCyan.copy(alpha = 0.05f),
)

// ============================================================
// Light Color Scheme (fallback, rarely used for pro audio)
// ============================================================
private val VaporwaveLightColorScheme = lightColorScheme(
    primary = Color(0xFF008B8B),        // Dark cyan
    secondary = Color(0xFFC71585),      // Medium violet red
    tertiary = Color(0xFF6A0DAD),       // Purple
    background = Color(0xFFF8F0FF),
    surface = Color.White,
)

// ============================================================
// Typography
// ============================================================
val EchoelTypography = Typography(
    displayLarge = TextStyle(
        fontWeight = FontWeight.Light,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = (-0.25).sp
    ),
    displayMedium = TextStyle(
        fontWeight = FontWeight.Light,
        fontSize = 45.sp,
        lineHeight = 52.sp
    ),
    headlineLarge = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 32.sp,
        lineHeight = 40.sp
    ),
    headlineMedium = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 28.sp,
        lineHeight = 36.sp
    ),
    headlineSmall = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp,
        lineHeight = 32.sp
    ),
    titleLarge = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        lineHeight = 28.sp
    ),
    titleMedium = TextStyle(
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp
    ),
    titleSmall = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    bodyLarge = TextStyle(
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    bodyMedium = TextStyle(
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp
    ),
    labelLarge = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp
    ),
    labelMedium = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    ),
    labelSmall = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    ),
)

/**
 * EchoelmusicTheme - Vaporwave dark theme composable
 *
 * @param darkTheme Always true for pro audio (reduces eye strain in studio)
 * @param dynamicColor Disabled by default to preserve Vaporwave brand
 */
@Composable
fun EchoelmusicTheme(
    darkTheme: Boolean = true,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> VaporwaveDarkColorScheme
        else -> VaporwaveLightColorScheme
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            window.navigationBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = !darkTheme
                isAppearanceLightNavigationBars = !darkTheme
            }
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = EchoelTypography,
        content = content
    )
}

// ============================================================
// Color Extensions for direct access throughout the app
// ============================================================
object EchoelColors {
    // Primary Vaporwave
    val neonCyan = NeonCyan
    val neonPink = NeonPink
    val neonPurple = NeonPurple
    val deepBlack = DeepBlack

    // Extended
    val magenta = VaporwaveMagenta
    val lavender = VaporwaveLavender
    val hotPink = VaporwaveHotPink
    val sunset = VaporwaveSunset
    val gold = VaporwaveGold
    val mint = VaporwaveMint

    // Backgrounds
    val bgDeep = VaporBgDeep
    val bgDarkBlue = VaporBgDarkBlue
    val bgMidnight = VaporBgMidnight
    val bgSurface = VaporBgSurface
    val bgElevated = VaporBgElevated
    val bgDeepPurple = VaporBgDeepPurple

    // Text
    val textPrimary = VaporTextPrimary
    val textSecondary = VaporTextSecondary
    val textTertiary = VaporTextTertiary

    // Bio-reactive
    val coherenceLow = CoherenceLow
    val coherenceMedium = CoherenceMedium
    val coherenceHigh = CoherenceHigh

    // Brainwave states
    val brainwaveDelta = BrainwaveDelta
    val brainwaveTheta = BrainwaveTheta
    val brainwaveAlpha = BrainwaveAlpha
    val brainwaveBeta = BrainwaveBeta
    val brainwaveGamma = BrainwaveGamma

    // Gradient presets
    val backgroundGradientColors = listOf(VaporBgDarkBlue, VaporBgDeepPurple, VaporBgDeep)
    val neonGradientColors = listOf(NeonCyan, NeonPurple, NeonPink)
    val sunsetGradientColors = listOf(NeonPink, NeonPurple, VaporBgDarkBlue)
}
