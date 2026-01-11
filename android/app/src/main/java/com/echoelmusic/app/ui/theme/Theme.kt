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
import androidx.core.view.WindowCompat

/**
 * Echoelmusic Artist Brand Theme (2026)
 *
 * Professional Audio + Wellness Trust Palette
 * Based on:
 * - Apple Human Interface Guidelines
 * - Material Design 3
 * - Pro Audio Industry Standards (Ableton, Logic Pro, Native Instruments)
 * - WCAG 2.2 AAA Accessibility
 */

// MARK: - Primary Brand Colors
private val EchoelTeal = Color(0xFF2DD4BF)      // Primary - confidence, technology, wellness
private val EchoelRose = Color(0xFFF472B6)      // Secondary - heart, bio-reactive, human
private val EchoelViolet = Color(0xFFA78BFA)    // Accent - creativity, premium

// MARK: - Extended Palette
private val EchoelEmerald = Color(0xFF34D399)   // Health, success
private val EchoelSky = Color(0xFF38BDF8)       // Science, trust
private val EchoelAmber = Color(0xFFFBBF24)     // Energy, warmth
private val EchoelCoral = Color(0xFFFB7366)     // Warning, attention

// MARK: - Background System
private val EchoelBgDeep = Color(0xFF0C0A1A)    // Primary background
private val EchoelBgSurface = Color(0xFF151326) // Cards, panels
private val EchoelBgElevated = Color(0xFF1A1730) // Modals, popovers

// MARK: - Text Colors
private val EchoelTextPrimary = Color(0xFFF8FAFC)
private val EchoelTextSecondary = Color(0xBFF8FAFC)  // 75% opacity
private val EchoelTextTertiary = Color(0x73F8FAFC)   // 45% opacity

// MARK: - Bio-Reactive Colors
private val CoherenceLow = Color(0xFFFB7366)
private val CoherenceMedium = Color(0xFFFBBF24)
private val CoherenceHigh = Color(0xFF2DD4BF)

// MARK: - Dark Color Scheme (Pro Audio Standard)
private val DarkColorScheme = darkColorScheme(
    primary = EchoelTeal,
    onPrimary = EchoelBgDeep,
    primaryContainer = EchoelTeal.copy(alpha = 0.2f),
    onPrimaryContainer = EchoelTeal,

    secondary = EchoelRose,
    onSecondary = EchoelBgDeep,
    secondaryContainer = EchoelRose.copy(alpha = 0.2f),
    onSecondaryContainer = EchoelRose,

    tertiary = EchoelViolet,
    onTertiary = EchoelBgDeep,
    tertiaryContainer = EchoelViolet.copy(alpha = 0.2f),
    onTertiaryContainer = EchoelViolet,

    background = EchoelBgDeep,
    onBackground = EchoelTextPrimary,

    surface = EchoelBgSurface,
    onSurface = EchoelTextPrimary,

    surfaceVariant = EchoelBgElevated,
    onSurfaceVariant = EchoelTextSecondary,

    error = EchoelCoral,
    onError = Color.White,

    outline = Color.White.copy(alpha = 0.08f),
    outlineVariant = Color.White.copy(alpha = 0.04f),
)

// MARK: - Light Color Scheme (for accessibility)
private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF0D9488),      // Darker teal for light mode
    secondary = Color(0xFFDB2777),    // Darker rose
    tertiary = Color(0xFF7C3AED),     // Darker violet
    background = Color(0xFFF8FAFC),
    surface = Color.White,
)

/**
 * Echoelmusic Theme Composable
 *
 * @param darkTheme Always true for pro audio apps (reduces eye strain)
 * @param dynamicColor Disabled by default to maintain brand consistency
 */
@Composable
fun EchoelmusicTheme(
    darkTheme: Boolean = true,          // Pro audio standard: always dark
    dynamicColor: Boolean = false,       // Use brand colors, not system
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        // Allow dynamic color on Android 12+ if explicitly requested
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            // Use brand background for system bars
            window.statusBarColor = colorScheme.background.toArgb()
            window.navigationBarColor = colorScheme.background.toArgb()
            // Light icons on dark background
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

/**
 * Custom typography following brand guidelines
 */
val EchoelTypography = Typography(
    // Uses Material 3 defaults with system fonts
    // Pro audio apps benefit from clean, readable typography
)

// MARK: - Brand Color Extensions
object EchoelColors {
    val teal = EchoelTeal
    val rose = EchoelRose
    val violet = EchoelViolet
    val emerald = EchoelEmerald
    val sky = EchoelSky
    val amber = EchoelAmber
    val coral = EchoelCoral

    val bgDeep = EchoelBgDeep
    val bgSurface = EchoelBgSurface
    val bgElevated = EchoelBgElevated

    val textPrimary = EchoelTextPrimary
    val textSecondary = EchoelTextSecondary
    val textTertiary = EchoelTextTertiary

    // Bio-reactive
    val coherenceLow = CoherenceLow
    val coherenceMedium = CoherenceMedium
    val coherenceHigh = CoherenceHigh

    // Brainwave colors (UI differentiation only, NOT therapeutic claims)
    val brainwaveDelta = Color(0xFF8B5CF6)   // Violet
    val brainwaveTheta = Color(0xFF38BDF8)   // Sky
    val brainwaveAlpha = Color(0xFF34D399)   // Emerald
    val brainwaveBeta = Color(0xFFFBBF24)    // Amber
    val brainwaveGamma = Color(0xFFF472B6)   // Rose
}
