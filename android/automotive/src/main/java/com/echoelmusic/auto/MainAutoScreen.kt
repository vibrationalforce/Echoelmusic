/**
 * MainAutoScreen.kt
 * Echoelmusic Android Auto Main Screen
 *
 * Driving-safe interface for bio-reactive audio
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.auto

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*

class MainAutoScreen(carContext: CarContext) : Screen(carContext) {

    private var isPlaying = false
    private var currentPreset = "Calm Drive"
    private var coherenceLevel = "Medium"

    override fun onGetTemplate(): Template {
        return PaneTemplate.Builder(createPane())
            .setTitle("Echoelmusic")
            .setHeaderAction(Action.APP_ICON)
            .setActionStrip(createActionStrip())
            .build()
    }

    private fun createPane(): Pane {
        return Pane.Builder()
            .addRow(createNowPlayingRow())
            .addRow(createCoherenceRow())
            .addRow(createPresetRow())
            .addAction(createPlayPauseAction())
            .addAction(createPresetsAction())
            .build()
    }

    private fun createNowPlayingRow(): Row {
        return Row.Builder()
            .setTitle("Bio-Reactive Audio")
            .addText(if (isPlaying) "▶ Playing" else "⏸ Paused")
            .setImage(
                CarIcon.Builder(
                    IconCompat.createWithResource(carContext, R.drawable.ic_music)
                ).build()
            )
            .build()
    }

    private fun createCoherenceRow(): Row {
        val coherenceText = when (coherenceLevel) {
            "High" -> "🟢 High Coherence"
            "Medium" -> "🟡 Medium Coherence"
            else -> "🟠 Building Coherence"
        }

        return Row.Builder()
            .setTitle("Coherence Status")
            .addText(coherenceText)
            .build()
    }

    private fun createPresetRow(): Row {
        return Row.Builder()
            .setTitle("Current Preset")
            .addText(currentPreset)
            .setBrowsable(true)
            .setOnClickListener {
                screenManager.push(PresetSelectionScreen(carContext))
            }
            .build()
    }

    private fun createPlayPauseAction(): Action {
        return Action.Builder()
            .setTitle(if (isPlaying) "Pause" else "Play")
            .setIcon(
                CarIcon.Builder(
                    IconCompat.createWithResource(
                        carContext,
                        if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play
                    )
                ).build()
            )
            .setOnClickListener {
                isPlaying = !isPlaying
                invalidate()
            }
            .build()
    }

    private fun createPresetsAction(): Action {
        return Action.Builder()
            .setTitle("Presets")
            .setIcon(
                CarIcon.Builder(
                    IconCompat.createWithResource(carContext, R.drawable.ic_preset)
                ).build()
            )
            .setOnClickListener {
                screenManager.push(PresetSelectionScreen(carContext))
            }
            .build()
    }

    private fun createActionStrip(): ActionStrip {
        return ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setTitle("Session")
                    .setOnClickListener {
                        screenManager.push(SessionScreen(carContext))
                    }
                    .build()
            )
            .build()
    }
}
