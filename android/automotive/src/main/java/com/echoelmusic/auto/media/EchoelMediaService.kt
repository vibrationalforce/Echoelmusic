/**
 * EchoelMediaService.kt
 * Echoelmusic Android Auto Media Browser Service
 *
 * Provides media browsing and playback for Android Auto
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.auto.media

import android.os.Bundle
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.media.MediaBrowserServiceCompat

class EchoelMediaService : MediaBrowserServiceCompat() {

    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var playbackState: PlaybackStateCompat.Builder

    companion object {
        private const val ROOT_ID = "echoelmusic_root"
        private const val PRESETS_ID = "presets"
        private const val SESSIONS_ID = "sessions"
    }

    // Media items representing bio-reactive presets
    private val presets = listOf(
        MediaItem(
            id = "preset_calm",
            title = "Calm Drive",
            subtitle = "Relaxing ambient for highway cruising",
            icon = "ic_calm"
        ),
        MediaItem(
            id = "preset_focus",
            title = "Focus Commute",
            subtitle = "Concentration-boosting for city driving",
            icon = "ic_focus"
        ),
        MediaItem(
            id = "preset_energy",
            title = "Energy Boost",
            subtitle = "Uplifting sounds for long trips",
            icon = "ic_energy"
        ),
        MediaItem(
            id = "preset_night",
            title = "Night Drive",
            subtitle = "Gentle ambience for evening journeys",
            icon = "ic_night"
        ),
        MediaItem(
            id = "preset_morning",
            title = "Morning Commute",
            subtitle = "Wake-up tones for early starts",
            icon = "ic_morning"
        ),
        MediaItem(
            id = "preset_stress",
            title = "Stress Relief",
            subtitle = "Calming audio for traffic jams",
            icon = "ic_stress"
        )
    )

    data class MediaItem(
        val id: String,
        val title: String,
        val subtitle: String,
        val icon: String
    )

    override fun onCreate() {
        super.onCreate()

        // Initialize media session
        mediaSession = MediaSessionCompat(this, "EchoelMediaService").apply {
            setCallback(MediaSessionCallback())
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
        }

        sessionToken = mediaSession.sessionToken

        // Initialize playback state
        playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_STOP or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
            .setState(PlaybackStateCompat.STATE_STOPPED, 0, 1.0f)

        mediaSession.setPlaybackState(playbackState.build())
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaSession.release()
    }

    override fun onGetRoot(
        clientPackageName: String,
        clientUid: Int,
        rootHints: Bundle?
    ): BrowserRoot {
        return BrowserRoot(ROOT_ID, null)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<MutableList<MediaBrowserCompat.MediaItem>>
    ) {
        val mediaItems = mutableListOf<MediaBrowserCompat.MediaItem>()

        when (parentId) {
            ROOT_ID -> {
                // Root level: show categories
                mediaItems.add(createBrowsableItem(PRESETS_ID, "Bio-Reactive Presets", "Driving-optimized audio experiences"))
                mediaItems.add(createBrowsableItem(SESSIONS_ID, "Recent Sessions", "Your coherence history"))
            }
            PRESETS_ID -> {
                // Presets list
                presets.forEach { preset ->
                    mediaItems.add(createPlayableItem(preset))
                }
            }
            SESSIONS_ID -> {
                // Recent sessions (placeholder)
                mediaItems.add(createPlayableItem(
                    MediaItem("session_1", "Today's Commute", "Avg. Coherence: 72%", "ic_session")
                ))
                mediaItems.add(createPlayableItem(
                    MediaItem("session_2", "Yesterday's Drive", "Avg. Coherence: 68%", "ic_session")
                ))
            }
        }

        result.sendResult(mediaItems)
    }

    private fun createBrowsableItem(id: String, title: String, subtitle: String): MediaBrowserCompat.MediaItem {
        val description = MediaDescriptionCompat.Builder()
            .setMediaId(id)
            .setTitle(title)
            .setSubtitle(subtitle)
            .build()

        return MediaBrowserCompat.MediaItem(
            description,
            MediaBrowserCompat.MediaItem.FLAG_BROWSABLE
        )
    }

    private fun createPlayableItem(item: MediaItem): MediaBrowserCompat.MediaItem {
        val description = MediaDescriptionCompat.Builder()
            .setMediaId(item.id)
            .setTitle(item.title)
            .setSubtitle(item.subtitle)
            .build()

        return MediaBrowserCompat.MediaItem(
            description,
            MediaBrowserCompat.MediaItem.FLAG_PLAYABLE
        )
    }

    // ========================================================================
    // MARK: - Media Session Callback
    // ========================================================================

    inner class MediaSessionCallback : MediaSessionCompat.Callback() {

        override fun onPlay() {
            mediaSession.isActive = true

            playbackState.setState(PlaybackStateCompat.STATE_PLAYING, 0, 1.0f)
            mediaSession.setPlaybackState(playbackState.build())

            // Start audio synthesis
            startAudioSynthesis()
        }

        override fun onPause() {
            playbackState.setState(PlaybackStateCompat.STATE_PAUSED, 0, 1.0f)
            mediaSession.setPlaybackState(playbackState.build())

            // Pause audio synthesis
            pauseAudioSynthesis()
        }

        override fun onStop() {
            mediaSession.isActive = false

            playbackState.setState(PlaybackStateCompat.STATE_STOPPED, 0, 1.0f)
            mediaSession.setPlaybackState(playbackState.build())

            // Stop audio synthesis
            stopAudioSynthesis()
        }

        override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
            mediaId?.let { id ->
                val preset = presets.find { it.id == id }
                preset?.let {
                    // Update metadata
                    val metadata = MediaMetadataCompat.Builder()
                        .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, it.id)
                        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, it.title)
                        .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "Echoelmusic")
                        .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, it.subtitle)
                        .build()

                    mediaSession.setMetadata(metadata)

                    // Start playback
                    onPlay()

                    // Apply preset
                    applyPreset(it.id)
                }
            }
        }

        override fun onSkipToNext() {
            // Skip to next preset
            val currentIndex = getCurrentPresetIndex()
            val nextIndex = (currentIndex + 1) % presets.size
            onPlayFromMediaId(presets[nextIndex].id, null)
        }

        override fun onSkipToPrevious() {
            // Skip to previous preset
            val currentIndex = getCurrentPresetIndex()
            val prevIndex = if (currentIndex > 0) currentIndex - 1 else presets.size - 1
            onPlayFromMediaId(presets[prevIndex].id, null)
        }

        private fun getCurrentPresetIndex(): Int {
            val currentMediaId = mediaSession.controller.metadata
                ?.getString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID)
            return presets.indexOfFirst { it.id == currentMediaId }.takeIf { it >= 0 } ?: 0
        }
    }

    // ========================================================================
    // MARK: - Audio Synthesis Control
    // ========================================================================

    private fun startAudioSynthesis() {
        // Send broadcast to main app to start audio
        val intent = android.content.Intent("com.echoelmusic.AUDIO_START")
        sendBroadcast(intent)
    }

    private fun pauseAudioSynthesis() {
        val intent = android.content.Intent("com.echoelmusic.AUDIO_PAUSE")
        sendBroadcast(intent)
    }

    private fun stopAudioSynthesis() {
        val intent = android.content.Intent("com.echoelmusic.AUDIO_STOP")
        sendBroadcast(intent)
    }

    private fun applyPreset(presetId: String) {
        val intent = android.content.Intent("com.echoelmusic.PRESET_CHANGED")
        intent.putExtra("preset_id", presetId)
        sendBroadcast(intent)
    }
}
