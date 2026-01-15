/**
 * Phase8000EnginesTest.kt
 * Comprehensive unit tests for Phase 8000 MAXIMUM OVERDRIVE engines
 *
 * Tests: Video, Creative, Scientific, Wellness, Collaboration
 *
 * Created: 2026-01-15
 */

package com.echoelmusic

import com.echoelmusic.engines.*
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.*

// ============================================================================
// VIDEO PROCESSING ENGINE TESTS
// ============================================================================

/**
 * Tests for VideoResolution enum
 */
class VideoResolutionTest {

    @Test
    fun `all resolutions have correct dimensions`() {
        assertEquals(854, VideoResolution.SD_480P.width)
        assertEquals(480, VideoResolution.SD_480P.height)

        assertEquals(1920, VideoResolution.FULL_HD_1080P.width)
        assertEquals(1080, VideoResolution.FULL_HD_1080P.height)

        assertEquals(3840, VideoResolution.UHD_4K.width)
        assertEquals(2160, VideoResolution.UHD_4K.height)

        assertEquals(7680, VideoResolution.UHD_8K.width)
        assertEquals(4320, VideoResolution.UHD_8K.height)

        assertEquals(15360, VideoResolution.QUANTUM_16K.width)
        assertEquals(8640, VideoResolution.QUANTUM_16K.height)
    }

    @Test
    fun `pixel count calculation correct`() {
        val fullHD = VideoResolution.FULL_HD_1080P
        assertEquals(1920 * 1080, fullHD.pixelCount)

        val uhd4k = VideoResolution.UHD_4K
        assertEquals(3840 * 2160, uhd4k.pixelCount)
    }

    @Test
    fun `bitrates increase with resolution`() {
        val resolutions = VideoResolution.values().sortedBy { it.pixelCount }
        for (i in 0 until resolutions.size - 1) {
            assertTrue(resolutions[i].bitrate <= resolutions[i + 1].bitrate)
        }
    }

    @Test
    fun `all resolutions have positive bitrate`() {
        VideoResolution.values().forEach { resolution ->
            assertTrue(resolution.bitrate > 0)
        }
    }

    @Test
    fun `resolution count matches expected`() {
        assertEquals(9, VideoResolution.values().size)
    }
}

/**
 * Tests for VideoFrameRate enum
 */
class VideoFrameRateTest {

    @Test
    fun `standard frame rates correct`() {
        assertEquals(24.0, VideoFrameRate.CINEMA_24.fps, 0.001)
        assertEquals(30.0, VideoFrameRate.STANDARD_30.fps, 0.001)
        assertEquals(60.0, VideoFrameRate.SMOOTH_60.fps, 0.001)
        assertEquals(120.0, VideoFrameRate.PROMOTION_120.fps, 0.001)
    }

    @Test
    fun `light speed frame rate is 1000fps`() {
        assertEquals(1000.0, VideoFrameRate.LIGHT_SPEED_1000.fps, 0.001)
    }

    @Test
    fun `all frame rates positive`() {
        VideoFrameRate.values().forEach { frameRate ->
            assertTrue(frameRate.fps > 0)
        }
    }

    @Test
    fun `frame rate count matches expected`() {
        assertEquals(12, VideoFrameRate.values().size)
    }

    @Test
    fun `frame rates in ascending order by value`() {
        val sorted = VideoFrameRate.values().sortedBy { it.fps }
        assertEquals(VideoFrameRate.CINEMA_24, sorted.first())
        assertEquals(VideoFrameRate.LIGHT_SPEED_1000, sorted.last())
    }
}

/**
 * Tests for VideoEffect enum
 */
class VideoEffectTest {

    @Test
    fun `basic effects exist`() {
        assertNotNull(VideoEffect.NONE)
        assertNotNull(VideoEffect.BLUR)
        assertNotNull(VideoEffect.SHARPEN)
    }

    @Test
    fun `quantum effects exist and require GPU`() {
        assertTrue(VideoEffect.QUANTUM_WAVE.requiresGPU)
        assertTrue(VideoEffect.COHERENCE_FIELD.requiresGPU)
        assertTrue(VideoEffect.PHOTON_TRAILS.requiresGPU)
        assertTrue(VideoEffect.ENTANGLEMENT.requiresGPU)
    }

    @Test
    fun `bio-reactive effects exist and require GPU`() {
        assertTrue(VideoEffect.HEARTBEAT_PULSE.requiresGPU)
        assertTrue(VideoEffect.BREATHING_WAVE.requiresGPU)
        assertTrue(VideoEffect.HRV_COHERENCE.requiresGPU)
    }

    @Test
    fun `cinematic effects exist`() {
        assertNotNull(VideoEffect.FILM_GRAIN)
        assertNotNull(VideoEffect.VIGNETTE)
        assertNotNull(VideoEffect.LENS_FLARE)
        assertNotNull(VideoEffect.BOKEH)
    }

    @Test
    fun `all effects have display names`() {
        VideoEffect.values().forEach { effect ->
            assertTrue(effect.displayName.isNotEmpty())
        }
    }

    @Test
    fun `none effect does not require GPU`() {
        assertFalse(VideoEffect.NONE.requiresGPU)
    }
}

/**
 * Tests for VideoStats data class
 */
class VideoStatsTest {

    @Test
    fun `default stats initialized correctly`() {
        val stats = VideoStats()
        assertEquals(0, stats.framesProcessed)
        assertEquals(0, stats.framesDropped)
        assertEquals(0.0, stats.currentFPS, 0.001)
        assertEquals(0f, stats.gpuUtilization, 0.001f)
        assertEquals(0f, stats.cpuUtilization, 0.001f)
        assertEquals(0.0, stats.processingLatency, 0.001)
        assertEquals(0.5f, stats.quantumCoherence, 0.001f)
    }

    @Test
    fun `stats with custom values`() {
        val stats = VideoStats(
            framesProcessed = 1000,
            framesDropped = 5,
            currentFPS = 59.94,
            gpuUtilization = 0.75f,
            cpuUtilization = 0.30f,
            processingLatency = 0.002,
            quantumCoherence = 0.85f
        )
        assertEquals(1000, stats.framesProcessed)
        assertEquals(5, stats.framesDropped)
        assertEquals(59.94, stats.currentFPS, 0.001)
    }
}

// ============================================================================
// CREATIVE STUDIO ENGINE TESTS
// ============================================================================

/**
 * Tests for CreativeMode enum
 */
class CreativeModeTest {

    @Test
    fun `all creative modes exist`() {
        assertEquals(8, CreativeMode.values().size)
        assertNotNull(CreativeMode.PAINTING)
        assertNotNull(CreativeMode.ILLUSTRATION)
        assertNotNull(CreativeMode.GENERATIVE_ART)
        assertNotNull(CreativeMode.FRACTALS)
        assertNotNull(CreativeMode.QUANTUM_ART)
        assertNotNull(CreativeMode.MUSIC_COMPOSITION)
        assertNotNull(CreativeMode.SOUND_DESIGN)
        assertNotNull(CreativeMode.AI_ART)
    }

    @Test
    fun `all modes have display names`() {
        CreativeMode.values().forEach { mode ->
            assertTrue(mode.displayName.isNotEmpty())
        }
    }
}

/**
 * Tests for ArtStyle enum
 */
class ArtStyleTest {

    @Test
    fun `all art styles exist`() {
        assertEquals(10, ArtStyle.values().size)
        assertNotNull(ArtStyle.PHOTOREALISTIC)
        assertNotNull(ArtStyle.IMPRESSIONISM)
        assertNotNull(ArtStyle.CUBISM)
        assertNotNull(ArtStyle.SURREALISM)
        assertNotNull(ArtStyle.CYBERPUNK)
        assertNotNull(ArtStyle.SYNTHWAVE)
        assertNotNull(ArtStyle.SACRED_GEOMETRY)
        assertNotNull(ArtStyle.QUANTUM_GENERATED)
        assertNotNull(ArtStyle.PROCEDURAL)
        assertNotNull(ArtStyle.FRACTAL)
    }

    @Test
    fun `all styles have display names`() {
        ArtStyle.values().forEach { style ->
            assertTrue(style.displayName.isNotEmpty())
        }
    }
}

/**
 * Tests for MusicGenre enum
 */
class MusicGenreTest {

    @Test
    fun `all music genres exist`() {
        assertEquals(7, MusicGenre.values().size)
        assertNotNull(MusicGenre.AMBIENT)
        assertNotNull(MusicGenre.ELECTRONIC)
        assertNotNull(MusicGenre.CLASSICAL)
        assertNotNull(MusicGenre.JAZZ)
        assertNotNull(MusicGenre.MEDITATION)
        assertNotNull(MusicGenre.BINAURAL)
        assertNotNull(MusicGenre.QUANTUM_MUSIC)
    }

    @Test
    fun `binaural has correct display name`() {
        assertEquals("Multidimensional Brainwave Entrainment", MusicGenre.BINAURAL.displayName)
    }
}

/**
 * Tests for GenerationResult data class
 */
class GenerationResultTest {

    @Test
    fun `generation result has unique id`() {
        val result1 = GenerationResult(outputType = "image", prompt = "test")
        val result2 = GenerationResult(outputType = "image", prompt = "test")
        assertNotEquals(result1.id, result2.id)
    }

    @Test
    fun `generation result timestamp set automatically`() {
        val before = System.currentTimeMillis()
        val result = GenerationResult(outputType = "audio", prompt = "music")
        val after = System.currentTimeMillis()
        assertTrue(result.timestamp >= before)
        assertTrue(result.timestamp <= after)
    }

    @Test
    fun `generation result stores prompt correctly`() {
        val result = GenerationResult(
            outputType = "image",
            prompt = "A quantum landscape",
            style = ArtStyle.SURREALISM
        )
        assertEquals("A quantum landscape", result.prompt)
        assertEquals(ArtStyle.SURREALISM, result.style)
    }
}

// ============================================================================
// SCIENTIFIC VISUALIZATION ENGINE TESTS
// ============================================================================

/**
 * Tests for VisualizationType enum
 */
class ScientificVisualizationTypeTest {

    @Test
    fun `all visualization types exist`() {
        assertEquals(8, VisualizationType.values().size)
        assertNotNull(VisualizationType.QUANTUM_FIELD)
        assertNotNull(VisualizationType.WAVE_FUNCTION)
        assertNotNull(VisualizationType.PARTICLE_SYSTEM)
        assertNotNull(VisualizationType.MOLECULAR)
        assertNotNull(VisualizationType.GALAXY)
        assertNotNull(VisualizationType.FLUID_DYNAMICS)
        assertNotNull(VisualizationType.NETWORK_GRAPH)
        assertNotNull(VisualizationType.HEATMAP)
    }

    @Test
    fun `all types have display names`() {
        VisualizationType.values().forEach { type ->
            assertTrue(type.displayName.isNotEmpty())
        }
    }
}

/**
 * Tests for DataPoint data class
 */
class DataPointTest {

    @Test
    fun `data point has unique id`() {
        val p1 = DataPoint(values = listOf(1.0, 2.0))
        val p2 = DataPoint(values = listOf(1.0, 2.0))
        assertNotEquals(p1.id, p2.id)
    }

    @Test
    fun `data point x y z accessors`() {
        val point = DataPoint(values = listOf(1.0, 2.0, 3.0))
        assertEquals(1.0, point.x, 0.001)
        assertEquals(2.0, point.y, 0.001)
        assertEquals(3.0, point.z, 0.001)
    }

    @Test
    fun `data point missing dimensions return 0`() {
        val point = DataPoint(values = listOf(5.0))
        assertEquals(5.0, point.x, 0.001)
        assertEquals(0.0, point.y, 0.001)
        assertEquals(0.0, point.z, 0.001)
    }

    @Test
    fun `data point with label`() {
        val point = DataPoint(values = listOf(1.0), label = "Test Point")
        assertEquals("Test Point", point.label)
    }

    @Test
    fun `data point timestamp set automatically`() {
        val before = System.currentTimeMillis()
        val point = DataPoint(values = listOf(0.0))
        val after = System.currentTimeMillis()
        assertTrue(point.timestamp >= before)
        assertTrue(point.timestamp <= after)
    }
}

/**
 * Tests for Dataset data class
 */
class DatasetTest {

    @Test
    fun `dataset has unique id`() {
        val d1 = Dataset(name = "Test")
        val d2 = Dataset(name = "Test")
        assertNotEquals(d1.id, d2.id)
    }

    @Test
    fun `dataset add point`() {
        val dataset = Dataset(name = "Test")
        assertEquals(0, dataset.count)

        dataset.addPoint(DataPoint(values = listOf(1.0, 2.0)))
        assertEquals(1, dataset.count)

        dataset.addPoint(DataPoint(values = listOf(3.0, 4.0)))
        assertEquals(2, dataset.count)
    }

    @Test
    fun `dataset statistics calculation`() {
        val dataset = Dataset(name = "Test", dimensions = 1)
        dataset.addPoint(DataPoint(values = listOf(10.0)))
        dataset.addPoint(DataPoint(values = listOf(20.0)))
        dataset.addPoint(DataPoint(values = listOf(30.0)))
        dataset.addPoint(DataPoint(values = listOf(40.0)))
        dataset.addPoint(DataPoint(values = listOf(50.0)))

        val stats = dataset.statistics(0)
        assertEquals(5, stats.count)
        assertEquals(10.0, stats.min, 0.001)
        assertEquals(50.0, stats.max, 0.001)
        assertEquals(30.0, stats.mean, 0.001)
    }

    @Test
    fun `dataset empty statistics`() {
        val dataset = Dataset(name = "Empty")
        val stats = dataset.statistics(0)
        assertEquals(0, stats.count)
        assertEquals(0.0, stats.min, 0.001)
        assertEquals(0.0, stats.max, 0.001)
        assertEquals(0.0, stats.mean, 0.001)
    }
}

/**
 * Tests for DataStatistics data class
 */
class DataStatisticsTest {

    @Test
    fun `statistics from values`() {
        val values = listOf(2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0)
        val stats = DataStatistics.fromValues(values)

        assertEquals(8, stats.count)
        assertEquals(2.0, stats.min, 0.001)
        assertEquals(9.0, stats.max, 0.001)
        assertEquals(5.0, stats.mean, 0.001)
        assertEquals(2.0, stats.standardDeviation, 0.01)
    }

    @Test
    fun `statistics from empty list`() {
        val stats = DataStatistics.fromValues(emptyList())
        assertEquals(0, stats.count)
        assertEquals(0.0, stats.standardDeviation, 0.001)
    }

    @Test
    fun `statistics from single value`() {
        val stats = DataStatistics.fromValues(listOf(5.0))
        assertEquals(1, stats.count)
        assertEquals(5.0, stats.min, 0.001)
        assertEquals(5.0, stats.max, 0.001)
        assertEquals(5.0, stats.mean, 0.001)
        assertEquals(0.0, stats.standardDeviation, 0.001)
    }
}

// ============================================================================
// WELLNESS TRACKING ENGINE TESTS
// ============================================================================

/**
 * Tests for WellnessDisclaimer
 */
class WellnessDisclaimerTest {

    @Test
    fun `full disclaimer contains required text`() {
        assertTrue(WellnessDisclaimer.FULL.contains("NOT"))
        assertTrue(WellnessDisclaimer.FULL.contains("medical advice"))
        assertTrue(WellnessDisclaimer.FULL.contains("healthcare professional"))
    }

    @Test
    fun `short disclaimer is concise`() {
        assertTrue(WellnessDisclaimer.SHORT.length < 100)
        assertTrue(WellnessDisclaimer.SHORT.contains("wellness"))
    }
}

/**
 * Tests for WellnessCategory enum
 */
class WellnessCategoryTest {

    @Test
    fun `all wellness categories exist`() {
        assertEquals(7, WellnessCategory.values().size)
        assertNotNull(WellnessCategory.RELAXATION)
        assertNotNull(WellnessCategory.MEDITATION)
        assertNotNull(WellnessCategory.BREATHWORK)
        assertNotNull(WellnessCategory.FOCUS)
        assertNotNull(WellnessCategory.SLEEP_SUPPORT)
        assertNotNull(WellnessCategory.MINDFULNESS)
        assertNotNull(WellnessCategory.GRATITUDE)
    }

    @Test
    fun `all categories have display names`() {
        WellnessCategory.values().forEach { category ->
            assertTrue(category.displayName.isNotEmpty())
        }
    }
}

/**
 * Tests for MoodLevel enum
 */
class MoodLevelTest {

    @Test
    fun `mood levels have correct values`() {
        assertEquals(1, MoodLevel.VERY_LOW.value)
        assertEquals(2, MoodLevel.LOW.value)
        assertEquals(3, MoodLevel.NEUTRAL.value)
        assertEquals(4, MoodLevel.GOOD.value)
        assertEquals(5, MoodLevel.GREAT.value)
    }

    @Test
    fun `mood levels have emojis`() {
        MoodLevel.values().forEach { mood ->
            assertTrue(mood.emoji.isNotEmpty())
        }
    }

    @Test
    fun `mood levels in ascending order`() {
        val sorted = MoodLevel.values().sortedBy { it.value }
        assertEquals(MoodLevel.VERY_LOW, sorted.first())
        assertEquals(MoodLevel.GREAT, sorted.last())
    }
}

/**
 * Tests for BreathingPattern data class
 */
class BreathingPatternTest {

    @Test
    fun `box breathing pattern correct`() {
        val box = BreathingPattern.BOX_BREATHING
        assertEquals("Box Breathing", box.name)
        assertEquals(4.0, box.inhaleSeconds, 0.001)
        assertEquals(4.0, box.holdInSeconds, 0.001)
        assertEquals(4.0, box.exhaleSeconds, 0.001)
        assertEquals(4.0, box.holdOutSeconds, 0.001)
        assertEquals(6, box.cycles)
    }

    @Test
    fun `relaxing 4-7-8 pattern correct`() {
        val pattern = BreathingPattern.RELAXING_478
        assertEquals("4-7-8 Relaxing", pattern.name)
        assertEquals(4.0, pattern.inhaleSeconds, 0.001)
        assertEquals(7.0, pattern.holdInSeconds, 0.001)
        assertEquals(8.0, pattern.exhaleSeconds, 0.001)
        assertEquals(0.0, pattern.holdOutSeconds, 0.001)
    }

    @Test
    fun `coherence breathing pattern correct`() {
        val pattern = BreathingPattern.COHERENCE
        assertEquals(5.0, pattern.inhaleSeconds, 0.001)
        assertEquals(0.0, pattern.holdInSeconds, 0.001)
        assertEquals(5.0, pattern.exhaleSeconds, 0.001)
        assertEquals(12, pattern.cycles)
    }

    @Test
    fun `cycle duration calculation`() {
        val box = BreathingPattern.BOX_BREATHING
        assertEquals(16.0, box.cycleDuration, 0.001) // 4+4+4+4 = 16

        val coherence = BreathingPattern.COHERENCE
        assertEquals(10.0, coherence.cycleDuration, 0.001) // 5+0+5+0 = 10
    }

    @Test
    fun `total duration calculation`() {
        val box = BreathingPattern.BOX_BREATHING
        assertEquals(96.0, box.totalDuration, 0.001) // 16 * 6 = 96

        val coherence = BreathingPattern.COHERENCE
        assertEquals(120.0, coherence.totalDuration, 0.001) // 10 * 12 = 120
    }

    @Test
    fun `all patterns list`() {
        assertEquals(3, BreathingPattern.ALL.size)
    }
}

/**
 * Tests for WellnessSession data class
 */
class WellnessSessionTest {

    @Test
    fun `session has unique id`() {
        val s1 = WellnessSession(name = "Test", category = WellnessCategory.MEDITATION)
        val s2 = WellnessSession(name = "Test", category = WellnessCategory.MEDITATION)
        assertNotEquals(s1.id, s2.id)
    }

    @Test
    fun `session incomplete by default`() {
        val session = WellnessSession(name = "Test", category = WellnessCategory.RELAXATION)
        assertFalse(session.isComplete)
    }

    @Test
    fun `session complete when end time set`() {
        val session = WellnessSession(name = "Test", category = WellnessCategory.FOCUS)
        session.endTime = System.currentTimeMillis()
        assertTrue(session.isComplete)
    }

    @Test
    fun `session duration calculation`() {
        val session = WellnessSession(name = "Test", category = WellnessCategory.BREATHWORK)
        Thread.sleep(100) // Wait 100ms
        session.endTime = System.currentTimeMillis()
        // Duration should be at least 0 minutes
        assertTrue(session.durationMinutes >= 0)
    }

    @Test
    fun `session with mood tracking`() {
        val session = WellnessSession(
            name = "Morning Meditation",
            category = WellnessCategory.MEDITATION,
            moodBefore = MoodLevel.NEUTRAL
        )
        assertEquals(MoodLevel.NEUTRAL, session.moodBefore)
        assertNull(session.moodAfter)

        session.moodAfter = MoodLevel.GOOD
        assertEquals(MoodLevel.GOOD, session.moodAfter)
    }
}

// ============================================================================
// WORLDWIDE COLLABORATION HUB TESTS
// ============================================================================

/**
 * Tests for CollaborationMode enum
 */
class CollaborationModeTest {

    @Test
    fun `all collaboration modes exist`() {
        assertEquals(6, CollaborationMode.values().size)
        assertNotNull(CollaborationMode.MUSIC_JAM)
        assertNotNull(CollaborationMode.GROUP_MEDITATION)
        assertNotNull(CollaborationMode.ART_COLLABORATION)
        assertNotNull(CollaborationMode.RESEARCH_SESSION)
        assertNotNull(CollaborationMode.COHERENCE_SYNC)
        assertNotNull(CollaborationMode.WORKSHOP)
    }

    @Test
    fun `max participants correct`() {
        assertEquals(8, CollaborationMode.MUSIC_JAM.maxParticipants)
        assertEquals(100, CollaborationMode.GROUP_MEDITATION.maxParticipants)
        assertEquals(12, CollaborationMode.ART_COLLABORATION.maxParticipants)
        assertEquals(20, CollaborationMode.RESEARCH_SESSION.maxParticipants)
        assertEquals(1000, CollaborationMode.COHERENCE_SYNC.maxParticipants)
        assertEquals(30, CollaborationMode.WORKSHOP.maxParticipants)
    }

    @Test
    fun `all modes have display names`() {
        CollaborationMode.values().forEach { mode ->
            assertTrue(mode.displayName.isNotEmpty())
        }
    }
}

/**
 * Tests for Participant data class
 */
class ParticipantTest {

    @Test
    fun `participant has unique id`() {
        val p1 = Participant(displayName = "User1", location = "NYC")
        val p2 = Participant(displayName = "User2", location = "LA")
        assertNotEquals(p1.id, p2.id)
    }

    @Test
    fun `participant defaults`() {
        val participant = Participant(displayName = "Test", location = "Remote")
        assertEquals(ParticipantRole.CONTRIBUTOR, participant.role)
        assertTrue(participant.isActive)
        assertTrue(participant.audioEnabled)
    }

    @Test
    fun `participant with custom role`() {
        val host = Participant(
            displayName = "Host",
            location = "Studio",
            role = ParticipantRole.HOST
        )
        assertEquals(ParticipantRole.HOST, host.role)
    }
}

/**
 * Tests for ParticipantRole enum
 */
class ParticipantRoleTest {

    @Test
    fun `all roles exist`() {
        assertEquals(4, ParticipantRole.values().size)
        assertNotNull(ParticipantRole.HOST)
        assertNotNull(ParticipantRole.CO_HOST)
        assertNotNull(ParticipantRole.CONTRIBUTOR)
        assertNotNull(ParticipantRole.VIEWER)
    }
}

/**
 * Tests for CollaborationSession data class
 */
class CollaborationSessionTest {

    @Test
    fun `session has unique id`() {
        val s1 = CollaborationSession(name = "Session1", mode = CollaborationMode.MUSIC_JAM, hostId = "host1")
        val s2 = CollaborationSession(name = "Session2", mode = CollaborationMode.MUSIC_JAM, hostId = "host2")
        assertNotEquals(s1.id, s2.id)
    }

    @Test
    fun `session code is 6 characters`() {
        val session = CollaborationSession(name = "Test", mode = CollaborationMode.WORKSHOP, hostId = "host")
        assertEquals(6, session.code.length)
    }

    @Test
    fun `session code contains valid characters`() {
        val session = CollaborationSession(name = "Test", mode = CollaborationMode.RESEARCH_SESSION, hostId = "host")
        val validChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        session.code.forEach { char ->
            assertTrue(validChars.contains(char))
        }
    }

    @Test
    fun `session participant count`() {
        val session = CollaborationSession(name = "Test", mode = CollaborationMode.GROUP_MEDITATION, hostId = "host")
        assertEquals(0, session.participantCount)

        session.participants.add(Participant(displayName = "User1", location = "NYC"))
        assertEquals(1, session.participantCount)

        session.participants.add(Participant(displayName = "User2", location = "LA", isActive = false))
        assertEquals(1, session.participantCount) // Only active participants counted
    }

    @Test
    fun `session defaults`() {
        val session = CollaborationSession(name = "Test", mode = CollaborationMode.COHERENCE_SYNC, hostId = "host")
        assertFalse(session.isActive)
        assertEquals(0.5f, session.sharedCoherence, 0.001f)
    }
}

/**
 * Tests for CollaborationRegion enum
 */
class CollaborationRegionTest {

    @Test
    fun `all regions exist`() {
        assertEquals(6, CollaborationRegion.values().size)
        assertNotNull(CollaborationRegion.US_EAST)
        assertNotNull(CollaborationRegion.US_WEST)
        assertNotNull(CollaborationRegion.EU_WEST)
        assertNotNull(CollaborationRegion.EU_CENTRAL)
        assertNotNull(CollaborationRegion.AP_NORTHEAST)
        assertNotNull(CollaborationRegion.QUANTUM_GLOBAL)
    }

    @Test
    fun `all regions have endpoints`() {
        CollaborationRegion.values().forEach { region ->
            assertTrue(region.endpoint.isNotEmpty())
            assertTrue(region.endpoint.contains("echoelmusic.com"))
        }
    }

    @Test
    fun `quantum global endpoint correct`() {
        assertEquals("quantum.echoelmusic.com", CollaborationRegion.QUANTUM_GLOBAL.endpoint)
    }
}
