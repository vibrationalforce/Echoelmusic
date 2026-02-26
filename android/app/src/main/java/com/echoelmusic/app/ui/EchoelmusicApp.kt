package com.echoelmusic.app.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.echoelmusic.app.ui.screens.*
import com.echoelmusic.app.ui.theme.EchoelColors
import com.echoelmusic.app.viewmodel.EchoelmusicViewModel

/**
 * Navigation route definitions
 */
sealed class Screen(val route: String, val title: String, val icon: ImageVector) {
    data object Main : Screen("main", "Home", Icons.Default.Home)
    data object Synth : Screen("synth", "Synth", Icons.Default.Piano)
    data object Binaural : Screen("binaural", "Binaural", Icons.Default.Waves)
    data object Bio : Screen("bio", "Bio", Icons.Default.FavoriteBorder)
    data object Settings : Screen("settings", "Settings", Icons.Default.Settings)
}

private val bottomNavItems = listOf(
    Screen.Main,
    Screen.Synth,
    Screen.Binaural,
    Screen.Bio,
    Screen.Settings
)

/**
 * Main Echoelmusic App UI
 * Jetpack Compose with Material 3 + Vaporwave Dark Theme
 *
 * All composables receive viewModel as parameter (no singletons).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EchoelmusicApp(viewModel: EchoelmusicViewModel) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Bio-reactive state from ViewModel
    val heartRate by viewModel.heartRate.collectAsState()
    val coherence by viewModel.coherence.collectAsState()
    val isPlaying by viewModel.isPlaying.collectAsState()

    // Animated background color based on coherence level
    val bgTopColor by animateColorAsState(
        targetValue = when {
            coherence > 0.8f -> EchoelColors.bgDarkBlue
            coherence > 0.5f -> EchoelColors.bgMidnight
            else -> EchoelColors.bgDeepPurple
        },
        animationSpec = tween(durationMillis = 2000),
        label = "bgTop"
    )

    val bgBottomColor by animateColorAsState(
        targetValue = when {
            coherence > 0.8f -> EchoelColors.bgMidnight
            coherence > 0.5f -> EchoelColors.bgDeepPurple
            else -> EchoelColors.bgDeep
        },
        animationSpec = tween(durationMillis = 2000),
        label = "bgBottom"
    )

    // Animated FAB glow intensity based on playback
    val fabGlow by animateFloatAsState(
        targetValue = if (isPlaying) 0.8f else 0f,
        animationSpec = tween(durationMillis = 500),
        label = "fabGlow"
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        // Animated pulse indicator
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isPlaying) EchoelColors.neonCyan
                                    else EchoelColors.textTertiary
                                )
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            "Echoelmusic",
                            fontWeight = FontWeight.Bold,
                            color = EchoelColors.textPrimary
                        )
                    }
                },
                actions = {
                    // Bio status chip in top bar
                    BioStatusChip(heartRate = heartRate, coherence = coherence)
                    Spacer(modifier = Modifier.width(8.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    scrolledContainerColor = EchoelColors.bgDeep.copy(alpha = 0.95f)
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = EchoelColors.bgDeep.copy(alpha = 0.95f),
                contentColor = EchoelColors.textPrimary,
                tonalElevation = 0.dp
            ) {
                bottomNavItems.forEach { screen ->
                    val selected = currentRoute == screen.route
                    NavigationBarItem(
                        icon = {
                            Icon(
                                screen.icon,
                                contentDescription = screen.title,
                                tint = if (selected) EchoelColors.neonCyan
                                       else EchoelColors.textTertiary
                            )
                        },
                        label = {
                            Text(
                                screen.title,
                                color = if (selected) EchoelColors.neonCyan
                                        else EchoelColors.textTertiary,
                                style = MaterialTheme.typography.labelSmall
                            )
                        },
                        selected = selected,
                        onClick = {
                            if (currentRoute != screen.route) {
                                navController.navigate(screen.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = EchoelColors.neonCyan,
                            selectedTextColor = EchoelColors.neonCyan,
                            unselectedIconColor = EchoelColors.textTertiary,
                            unselectedTextColor = EchoelColors.textTertiary,
                            indicatorColor = EchoelColors.neonCyan.copy(alpha = 0.12f)
                        )
                    )
                }
            }
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.togglePlayback() },
                containerColor = if (isPlaying) EchoelColors.neonPink
                                 else EchoelColors.neonCyan,
                contentColor = EchoelColors.deepBlack,
                modifier = Modifier.shadow(
                    elevation = if (isPlaying) 16.dp else 6.dp,
                    shape = CircleShape,
                    ambientColor = if (isPlaying) EchoelColors.neonPink.copy(alpha = fabGlow)
                                   else Color.Transparent,
                    spotColor = if (isPlaying) EchoelColors.neonPink.copy(alpha = fabGlow)
                                else Color.Transparent
                )
            ) {
                Icon(
                    if (isPlaying) Icons.Default.Stop else Icons.Default.PlayArrow,
                    contentDescription = if (isPlaying) "Stop" else "Play"
                )
            }
        },
        containerColor = Color.Transparent
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            bgTopColor,
                            bgBottomColor,
                            EchoelColors.bgDeep
                        )
                    )
                )
                .padding(paddingValues)
        ) {
            NavHost(
                navController = navController,
                startDestination = Screen.Main.route
            ) {
                composable(Screen.Main.route) { MainDashboardScreen(viewModel = viewModel) }
                composable(Screen.Synth.route) { SynthScreen(viewModel = viewModel) }
                composable(Screen.Binaural.route) { BinauralBeatsScreen(viewModel = viewModel) }
                composable(Screen.Bio.route) { BioReactiveScreen(viewModel = viewModel) }
                composable(Screen.Settings.route) { SettingsScreen(viewModel = viewModel) }
            }
        }
    }
}

/**
 * Bio status chip shown in the top app bar.
 * Displays heart rate and coherence with color-coded indicator.
 */
@Composable
fun BioStatusChip(heartRate: Float, coherence: Float) {
    val coherenceColor by animateColorAsState(
        targetValue = when {
            coherence > 0.8f -> EchoelColors.coherenceHigh
            coherence > 0.5f -> EchoelColors.coherenceMedium
            else -> EchoelColors.coherenceLow
        },
        animationSpec = tween(durationMillis = 1000),
        label = "coherenceColor"
    )

    Surface(
        shape = RoundedCornerShape(20.dp),
        color = EchoelColors.bgElevated.copy(alpha = 0.8f),
        shadowElevation = 2.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Heart rate
            Icon(
                Icons.Default.Favorite,
                contentDescription = "Heart rate",
                tint = EchoelColors.neonPink,
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                "${heartRate.toInt()}",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textPrimary
            )

            Spacer(modifier = Modifier.width(10.dp))

            // Coherence indicator dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(coherenceColor)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                "${(coherence * 100).toInt()}%",
                style = MaterialTheme.typography.labelMedium,
                color = EchoelColors.textPrimary
            )
        }
    }
}
