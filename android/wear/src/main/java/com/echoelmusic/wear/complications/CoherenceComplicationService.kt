/**
 * CoherenceComplicationService.kt
 * Echoelmusic Wear OS Watch Face Complications
 *
 * Provides real-time coherence and HRV data to watch faces
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.wear.complications

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.*
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import com.echoelmusic.wear.R
import com.echoelmusic.wear.WearMainActivity

/**
 * Coherence Level Complication
 * Shows current coherence as a gauge/text
 */
class CoherenceComplicationService : ComplicationDataSourceService() {

    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationRequestListener
    ) {
        // Get current coherence from shared preferences or data store
        val prefs = applicationContext.getSharedPreferences("bio_data", MODE_PRIVATE)
        val coherence = prefs.getFloat("coherence", 0.5f)
        val coherenceLevel = when {
            coherence >= 0.7f -> "High"
            coherence >= 0.4f -> "Medium"
            else -> "Low"
        }

        val complicationData = when (request.complicationType) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication(coherence, coherenceLevel)
            ComplicationType.LONG_TEXT -> createLongTextComplication(coherence, coherenceLevel)
            ComplicationType.RANGED_VALUE -> createRangedValueComplication(coherence)
            ComplicationType.MONOCHROMATIC_IMAGE -> createMonochromaticImageComplication()
            ComplicationType.SMALL_IMAGE -> createSmallImageComplication()
            else -> null
        }

        listener.onComplicationData(complicationData)
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        return when (type) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication(0.75f, "High")
            ComplicationType.LONG_TEXT -> createLongTextComplication(0.75f, "High")
            ComplicationType.RANGED_VALUE -> createRangedValueComplication(0.75f)
            else -> null
        }
    }

    private fun createShortTextComplication(coherence: Float, level: String): ShortTextComplicationData {
        return ShortTextComplicationData.Builder(
            text = PlainComplicationText.Builder("${(coherence * 100).toInt()}%").build(),
            contentDescription = PlainComplicationText.Builder("Coherence $level").build()
        )
            .setTitle(PlainComplicationText.Builder("Coh").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createLongTextComplication(coherence: Float, level: String): LongTextComplicationData {
        return LongTextComplicationData.Builder(
            text = PlainComplicationText.Builder("Coherence: $level").build(),
            contentDescription = PlainComplicationText.Builder("Coherence level $level at ${(coherence * 100).toInt()}%").build()
        )
            .setTitle(PlainComplicationText.Builder("${(coherence * 100).toInt()}%").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createRangedValueComplication(coherence: Float): RangedValueComplicationData {
        return RangedValueComplicationData.Builder(
            value = coherence,
            min = 0f,
            max = 1f,
            contentDescription = PlainComplicationText.Builder("Coherence ${(coherence * 100).toInt()}%").build()
        )
            .setText(PlainComplicationText.Builder("${(coherence * 100).toInt()}%").build())
            .setTitle(PlainComplicationText.Builder("Coherence").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createMonochromaticImageComplication(): MonochromaticImageComplicationData {
        return MonochromaticImageComplicationData.Builder(
            image = MonochromaticImage.Builder(
                Icon.createWithResource(this, R.drawable.ic_coherence)
            ).build(),
            contentDescription = PlainComplicationText.Builder("Echoelmusic").build()
        )
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createSmallImageComplication(): SmallImageComplicationData {
        return SmallImageComplicationData.Builder(
            smallImage = SmallImage.Builder(
                image = Icon.createWithResource(this, R.drawable.ic_coherence),
                type = SmallImageType.ICON
            ).build(),
            contentDescription = PlainComplicationText.Builder("Echoelmusic").build()
        )
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createLaunchIntent(): PendingIntent {
        val intent = Intent(this, WearMainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

/**
 * HRV Complication
 * Shows current Heart Rate Variability
 */
class HrvComplicationService : ComplicationDataSourceService() {

    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationRequestListener
    ) {
        val prefs = applicationContext.getSharedPreferences("bio_data", MODE_PRIVATE)
        val hrv = prefs.getFloat("hrv", 45f)

        val complicationData = when (request.complicationType) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication(hrv)
            ComplicationType.LONG_TEXT -> createLongTextComplication(hrv)
            ComplicationType.RANGED_VALUE -> createRangedValueComplication(hrv)
            else -> null
        }

        listener.onComplicationData(complicationData)
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        return when (type) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication(55f)
            ComplicationType.LONG_TEXT -> createLongTextComplication(55f)
            ComplicationType.RANGED_VALUE -> createRangedValueComplication(55f)
            else -> null
        }
    }

    private fun createShortTextComplication(hrv: Float): ShortTextComplicationData {
        return ShortTextComplicationData.Builder(
            text = PlainComplicationText.Builder("${hrv.toInt()}").build(),
            contentDescription = PlainComplicationText.Builder("HRV ${hrv.toInt()} ms").build()
        )
            .setTitle(PlainComplicationText.Builder("HRV").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createLongTextComplication(hrv: Float): LongTextComplicationData {
        return LongTextComplicationData.Builder(
            text = PlainComplicationText.Builder("HRV: ${hrv.toInt()} ms").build(),
            contentDescription = PlainComplicationText.Builder("Heart Rate Variability ${hrv.toInt()} milliseconds").build()
        )
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createRangedValueComplication(hrv: Float): RangedValueComplicationData {
        // HRV typically ranges from 20-100ms for most people
        val normalizedHrv = ((hrv - 20f) / 80f).coerceIn(0f, 1f)

        return RangedValueComplicationData.Builder(
            value = normalizedHrv,
            min = 0f,
            max = 1f,
            contentDescription = PlainComplicationText.Builder("HRV ${hrv.toInt()} ms").build()
        )
            .setText(PlainComplicationText.Builder("${hrv.toInt()}ms").build())
            .setTitle(PlainComplicationText.Builder("HRV").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createLaunchIntent(): PendingIntent {
        val intent = Intent(this, WearMainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

/**
 * Heart Rate Complication
 * Shows current heart rate with pulse indication
 */
class HeartRateComplicationService : ComplicationDataSourceService() {

    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationRequestListener
    ) {
        val prefs = applicationContext.getSharedPreferences("bio_data", MODE_PRIVATE)
        val heartRate = prefs.getInt("heartRate", 72)

        val complicationData = when (request.complicationType) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication(heartRate)
            ComplicationType.LONG_TEXT -> createLongTextComplication(heartRate)
            ComplicationType.RANGED_VALUE -> createRangedValueComplication(heartRate)
            else -> null
        }

        listener.onComplicationData(complicationData)
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        return when (type) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication(72)
            ComplicationType.LONG_TEXT -> createLongTextComplication(72)
            ComplicationType.RANGED_VALUE -> createRangedValueComplication(72)
            else -> null
        }
    }

    private fun createShortTextComplication(heartRate: Int): ShortTextComplicationData {
        return ShortTextComplicationData.Builder(
            text = PlainComplicationText.Builder("$heartRate").build(),
            contentDescription = PlainComplicationText.Builder("Heart rate $heartRate BPM").build()
        )
            .setTitle(PlainComplicationText.Builder("❤️").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createLongTextComplication(heartRate: Int): LongTextComplicationData {
        return LongTextComplicationData.Builder(
            text = PlainComplicationText.Builder("Heart Rate: $heartRate BPM").build(),
            contentDescription = PlainComplicationText.Builder("Heart rate $heartRate beats per minute").build()
        )
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createRangedValueComplication(heartRate: Int): RangedValueComplicationData {
        // Heart rate typically ranges from 40-180 BPM
        val normalizedHr = ((heartRate - 40f) / 140f).coerceIn(0f, 1f)

        return RangedValueComplicationData.Builder(
            value = normalizedHr,
            min = 0f,
            max = 1f,
            contentDescription = PlainComplicationText.Builder("Heart rate $heartRate BPM").build()
        )
            .setText(PlainComplicationText.Builder("$heartRate").build())
            .setTitle(PlainComplicationText.Builder("BPM").build())
            .setTapAction(createLaunchIntent())
            .build()
    }

    private fun createLaunchIntent(): PendingIntent {
        val intent = Intent(this, WearMainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
