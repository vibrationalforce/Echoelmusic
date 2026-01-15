/**
 * PresetSelectionScreen.kt
 * Echoelmusic Android Auto Preset Selection
 *
 * Driving-safe preset browser
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.auto

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*

/**
 * Driving-optimized preset categories
 */
enum class DrivingPreset(
    val displayName: String,
    val description: String,
    val iconRes: Int
) {
    CALM_DRIVE("Calm Drive", "Relaxing ambient for highway cruising", R.drawable.ic_calm),
    FOCUS_COMMUTE("Focus Commute", "Concentration-boosting for city driving", R.drawable.ic_focus),
    ENERGY_BOOST("Energy Boost", "Uplifting sounds for long trips", R.drawable.ic_energy),
    NIGHT_DRIVE("Night Drive", "Gentle ambience for evening journeys", R.drawable.ic_night),
    MORNING_COMMUTE("Morning Commute", "Wake-up tones for early starts", R.drawable.ic_morning),
    STRESS_RELIEF("Stress Relief", "Calming audio for traffic jams", R.drawable.ic_stress)
}

class PresetSelectionScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val itemList = ItemList.Builder()

        DrivingPreset.entries.forEach { preset ->
            itemList.addItem(
                Row.Builder()
                    .setTitle(preset.displayName)
                    .addText(preset.description)
                    .setImage(
                        CarIcon.Builder(
                            IconCompat.createWithResource(carContext, preset.iconRes)
                        ).build()
                    )
                    .setOnClickListener {
                        // Apply preset and go back
                        applyPreset(preset)
                        screenManager.pop()
                    }
                    .build()
            )
        }

        return ListTemplate.Builder()
            .setTitle("Select Preset")
            .setHeaderAction(Action.BACK)
            .setSingleList(itemList.build())
            .build()
    }

    private fun applyPreset(preset: DrivingPreset) {
        // Send preset selection to main app via broadcast or service binding
        val intent = android.content.Intent("com.echoelmusic.PRESET_CHANGED")
        intent.putExtra("preset_name", preset.name)
        carContext.sendBroadcast(intent)
    }
}

class SessionScreen(carContext: CarContext) : Screen(carContext) {

    private var sessionActive = false
    private var sessionDuration = 0L
    private var avgCoherence = 0.5f

    override fun onGetTemplate(): Template {
        return PaneTemplate.Builder(createPane())
            .setTitle("Session")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun createPane(): Pane {
        val builder = Pane.Builder()

        if (sessionActive) {
            builder.addRow(
                Row.Builder()
                    .setTitle("Session Active")
                    .addText("Duration: ${formatDuration(sessionDuration)}")
                    .build()
            )
            builder.addRow(
                Row.Builder()
                    .setTitle("Average Coherence")
                    .addText("${(avgCoherence * 100).toInt()}%")
                    .build()
            )
            builder.addAction(
                Action.Builder()
                    .setTitle("End Session")
                    .setBackgroundColor(CarColor.RED)
                    .setOnClickListener {
                        endSession()
                        invalidate()
                    }
                    .build()
            )
        } else {
            builder.addRow(
                Row.Builder()
                    .setTitle("No Active Session")
                    .addText("Start a session to track your coherence while driving")
                    .build()
            )
            builder.addAction(
                Action.Builder()
                    .setTitle("Start Session")
                    .setBackgroundColor(CarColor.GREEN)
                    .setOnClickListener {
                        startSession()
                        invalidate()
                    }
                    .build()
            )
        }

        return builder.build()
    }

    private fun startSession() {
        sessionActive = true
        sessionDuration = 0
        avgCoherence = 0f

        // Notify main app
        val intent = android.content.Intent("com.echoelmusic.SESSION_START")
        carContext.sendBroadcast(intent)
    }

    private fun endSession() {
        sessionActive = false

        // Notify main app
        val intent = android.content.Intent("com.echoelmusic.SESSION_END")
        carContext.sendBroadcast(intent)
    }

    private fun formatDuration(seconds: Long): String {
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        val secs = seconds % 60

        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, secs)
        } else {
            String.format("%02d:%02d", minutes, secs)
        }
    }
}
