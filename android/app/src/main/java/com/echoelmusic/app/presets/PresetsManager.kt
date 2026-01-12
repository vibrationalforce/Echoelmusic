package com.echoelmusic.app.presets

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.*

/**
 * Echoelmusic Presets Manager for Android
 * 50+ Expanded Presets across all categories
 * Bio-Reactive, Musical, Visual, Lighting, Streaming, Collaboration
 *
 * Port of iOS ExpandedPresets with Kotlin
 */

// MARK: - Engine Preset Interface

interface EnginePreset {
    val id: String
    val name: String
    val description: String
    val category: String
    val author: String
    val version: String
}

// MARK: - Bio-Reactive Presets

data class BioReactivePreset(
    override val id: String = UUID.randomUUID().toString(),
    override val name: String,
    override val description: String,
    override val category: String,
    override val author: String = "Echoelmusic",
    override val version: String = "1.0",
    val hrvCoherenceTarget: Double,
    val breathingRateTarget: Double,
    val heartRateModulation: Boolean,
    val coherenceModulation: Boolean,
    val breathModulation: Boolean,
    val audioParameters: Map<String, Double>,
    val visualParameters: Map<String, Double>,
    val lightingParameters: Map<String, Double>
) : EnginePreset {
    companion object {
        val DEEP_MEDITATION = BioReactivePreset(
            name = "Deep Meditation",
            description = "Ultra-deep meditative state with theta entrainment",
            category = "Meditation",
            hrvCoherenceTarget = 0.9,
            breathingRateTarget = 5.0,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 6.0, "reverbWetness" to 0.7, "filterCutoff" to 500.0, "volume" to 0.4),
            visualParameters = mapOf("brightness" to 0.2, "saturation" to 0.3, "speed" to 0.3),
            lightingParameters = mapOf("intensity" to 0.2, "colorTemp" to 2700.0, "transitionSpeed" to 0.1)
        )

        val ACTIVE_FLOW = BioReactivePreset(
            name = "Active Flow",
            description = "High-energy flow state for sports, dance, or creative work",
            category = "Performance",
            hrvCoherenceTarget = 0.7,
            breathingRateTarget = 16.0,
            heartRateModulation = true,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 18.0, "reverbWetness" to 0.2, "filterCutoff" to 8000.0, "volume" to 0.7),
            visualParameters = mapOf("brightness" to 0.8, "saturation" to 0.9, "speed" to 1.5),
            lightingParameters = mapOf("intensity" to 0.8, "colorTemp" to 6500.0, "transitionSpeed" to 0.8)
        )

        val SLEEP_INDUCTION = BioReactivePreset(
            name = "Sleep Induction",
            description = "Gentle transition to deep sleep with delta entrainment",
            category = "Sleep",
            hrvCoherenceTarget = 0.5,
            breathingRateTarget = 4.0,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 2.0, "reverbWetness" to 0.8, "filterCutoff" to 300.0, "volume" to 0.2),
            visualParameters = mapOf("brightness" to 0.05, "saturation" to 0.1, "speed" to 0.1),
            lightingParameters = mapOf("intensity" to 0.05, "colorTemp" to 1800.0, "transitionSpeed" to 0.05)
        )

        val MORNING_ENERGIZE = BioReactivePreset(
            name = "Morning Energize",
            description = "Bright, uplifting wake-up sequence with beta stimulation",
            category = "Energy",
            hrvCoherenceTarget = 0.6,
            breathingRateTarget = 14.0,
            heartRateModulation = true,
            coherenceModulation = false,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 20.0, "reverbWetness" to 0.15, "filterCutoff" to 10000.0, "volume" to 0.6),
            visualParameters = mapOf("brightness" to 0.9, "saturation" to 0.7, "speed" to 1.0),
            lightingParameters = mapOf("intensity" to 0.9, "colorTemp" to 5500.0, "transitionSpeed" to 0.5)
        )

        val FOCUS_ZONE = BioReactivePreset(
            name = "Focus Zone",
            description = "Laser-sharp concentration with gamma brainwave enhancement",
            category = "Focus",
            hrvCoherenceTarget = 0.8,
            breathingRateTarget = 12.0,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = false,
            audioParameters = mapOf("binauralFrequency" to 40.0, "reverbWetness" to 0.1, "filterCutoff" to 6000.0, "volume" to 0.5),
            visualParameters = mapOf("brightness" to 0.6, "saturation" to 0.4, "speed" to 0.5),
            lightingParameters = mapOf("intensity" to 0.6, "colorTemp" to 5000.0, "transitionSpeed" to 0.2)
        )

        val STRESS_RELIEF = BioReactivePreset(
            name = "Stress Relief",
            description = "Rapid stress reduction with alpha wave relaxation",
            category = "Wellness",
            hrvCoherenceTarget = 0.75,
            breathingRateTarget = 8.0,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 10.0, "reverbWetness" to 0.5, "filterCutoff" to 2000.0, "volume" to 0.45),
            visualParameters = mapOf("brightness" to 0.4, "saturation" to 0.5, "speed" to 0.4),
            lightingParameters = mapOf("intensity" to 0.4, "colorTemp" to 3500.0, "transitionSpeed" to 0.3)
        )

        val HEART_COHERENCE = BioReactivePreset(
            name = "Heart Coherence",
            description = "Maximum HRV coherence training with 5-second breathing rhythm",
            category = "Biofeedback",
            hrvCoherenceTarget = 0.95,
            breathingRateTarget = 6.0,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 7.83, "reverbWetness" to 0.4, "filterCutoff" to 1000.0, "volume" to 0.5),
            visualParameters = mapOf("brightness" to 0.5, "saturation" to 0.6, "speed" to 0.5),
            lightingParameters = mapOf("intensity" to 0.5, "colorTemp" to 4000.0, "transitionSpeed" to 0.5)
        )

        val BREATH_SYNC = BioReactivePreset(
            name = "Breath Sync",
            description = "Perfect synchronization between breath and audio-visual elements",
            category = "Breathwork",
            hrvCoherenceTarget = 0.7,
            breathingRateTarget = 10.0,
            heartRateModulation = false,
            coherenceModulation = false,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 8.0, "reverbWetness" to 0.35, "filterCutoff" to 3000.0, "volume" to 0.5),
            visualParameters = mapOf("brightness" to 0.6, "saturation" to 0.7, "speed" to 0.6),
            lightingParameters = mapOf("intensity" to 0.6, "colorTemp" to 4500.0, "transitionSpeed" to 0.6)
        )

        val ZEN_MASTER = BioReactivePreset(
            name = "Zen Master",
            description = "Advanced meditation with minimal interference, pure awareness",
            category = "Meditation",
            hrvCoherenceTarget = 0.85,
            breathingRateTarget = 4.5,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 4.5, "reverbWetness" to 0.6, "filterCutoff" to 400.0, "volume" to 0.3),
            visualParameters = mapOf("brightness" to 0.15, "saturation" to 0.2, "speed" to 0.2),
            lightingParameters = mapOf("intensity" to 0.15, "colorTemp" to 2000.0, "transitionSpeed" to 0.15)
        )

        val QUANTUM_CALM = BioReactivePreset(
            name = "Quantum Calm",
            description = "Bio-coherent quantum field meditation for transcendent states",
            category = "Quantum",
            hrvCoherenceTarget = 0.9,
            breathingRateTarget = 5.5,
            heartRateModulation = false,
            coherenceModulation = true,
            breathModulation = true,
            audioParameters = mapOf("binauralFrequency" to 7.83, "reverbWetness" to 0.65, "filterCutoff" to 528.0, "volume" to 0.4),
            visualParameters = mapOf("brightness" to 0.3, "saturation" to 0.5, "speed" to 0.35),
            lightingParameters = mapOf("intensity" to 0.3, "colorTemp" to 3000.0, "transitionSpeed" to 0.25)
        )

        val ALL = listOf(
            DEEP_MEDITATION, ACTIVE_FLOW, SLEEP_INDUCTION, MORNING_ENERGIZE, FOCUS_ZONE,
            STRESS_RELIEF, HEART_COHERENCE, BREATH_SYNC, ZEN_MASTER, QUANTUM_CALM
        )
    }
}

// MARK: - Musical Presets

data class MusicalPreset(
    override val id: String = UUID.randomUUID().toString(),
    override val name: String,
    override val description: String,
    override val category: String,
    override val author: String = "Echoelmusic",
    override val version: String = "1.0",
    val bpm: Double,
    val key: String,
    val scale: String,
    val timeSignature: String,
    val effects: Map<String, Double>,
    val spatialMode: String,
    val spatialWidth: Double
) : EnginePreset {
    companion object {
        val AMBIENT_DRONE = MusicalPreset(
            name = "Ambient Drone",
            description = "Deep atmospheric drones with evolving textures",
            category = "Ambient",
            bpm = 0.0, key = "C", scale = "Aeolian", timeSignature = "4/4",
            effects = mapOf("reverbDecay" to 15.0, "reverbMix" to 0.8, "filterCutoff" to 1500.0, "delayTime" to 1.5),
            spatialMode = "ambisonics", spatialWidth = 1.0
        )

        val TECHNO_MINIMAL = MusicalPreset(
            name = "Techno Minimal",
            description = "Hypnotic minimal techno with tight drums",
            category = "Electronic",
            bpm = 132.0, key = "Am", scale = "Minor", timeSignature = "4/4",
            effects = mapOf("reverbDecay" to 1.2, "reverbMix" to 0.15, "filterCutoff" to 8000.0, "compression" to 0.7),
            spatialMode = "stereo", spatialWidth = 0.7
        )

        val CHILL_HOP = MusicalPreset(
            name = "Chill Hop",
            description = "Lo-fi hip-hop beats with warm vinyl crackle",
            category = "Hip-Hop",
            bpm = 85.0, key = "Dm", scale = "Dorian", timeSignature = "4/4",
            effects = mapOf("reverbDecay" to 2.5, "reverbMix" to 0.35, "filterCutoff" to 5000.0, "bitCrush" to 0.3),
            spatialMode = "stereo", spatialWidth = 0.5
        )

        val NEO_CLASSICAL = MusicalPreset(
            name = "Neo-Classical",
            description = "Modern classical composition with cinematic strings",
            category = "Classical",
            bpm = 72.0, key = "C", scale = "Major", timeSignature = "3/4",
            effects = mapOf("reverbDecay" to 3.5, "reverbMix" to 0.5, "filterCutoff" to 12000.0, "compression" to 0.3),
            spatialMode = "surround_3d", spatialWidth = 0.9
        )

        val SPACE_AMBIENT = MusicalPreset(
            name = "Space Ambient",
            description = "Cosmic soundscapes with ethereal pads",
            category = "Ambient",
            bpm = 0.0, key = "F#", scale = "Phrygian", timeSignature = "free",
            effects = mapOf("reverbDecay" to 20.0, "reverbMix" to 0.9, "filterCutoff" to 800.0, "shimmerReverb" to 0.7),
            spatialMode = "surround_4d", spatialWidth = 1.0
        )

        val TRIBAL_RHYTHM = MusicalPreset(
            name = "Tribal Rhythm",
            description = "Primal percussion with organic drums",
            category = "World",
            bpm = 118.0, key = "E", scale = "Phrygian Dominant", timeSignature = "7/8",
            effects = mapOf("reverbDecay" to 2.0, "reverbMix" to 0.25, "filterCutoff" to 6000.0, "distortion" to 0.2),
            spatialMode = "binaural", spatialWidth = 0.8
        )

        val CINEMATIC_EPIC = MusicalPreset(
            name = "Cinematic Epic",
            description = "Grand orchestral soundtrack with massive brass",
            category = "Film",
            bpm = 90.0, key = "D", scale = "Minor", timeSignature = "4/4",
            effects = mapOf("reverbDecay" to 4.0, "reverbMix" to 0.6, "filterCutoff" to 14000.0, "compression" to 0.5),
            spatialMode = "surround_5.1", spatialWidth = 1.0
        )

        val DARK_WAVE = MusicalPreset(
            name = "Dark Wave",
            description = "80s-inspired synth wave with cold atmosphere",
            category = "Electronic",
            bpm = 110.0, key = "Cm", scale = "Minor", timeSignature = "4/4",
            effects = mapOf("reverbDecay" to 2.0, "reverbMix" to 0.4, "filterCutoff" to 4000.0, "chorus" to 0.5),
            spatialMode = "stereo", spatialWidth = 0.6
        )

        val JAZZ_FUSION = MusicalPreset(
            name = "Jazz Fusion",
            description = "Complex jazz harmonies with electronic elements",
            category = "Jazz",
            bpm = 100.0, key = "Eb", scale = "Lydian Dominant", timeSignature = "5/4",
            effects = mapOf("reverbDecay" to 2.2, "reverbMix" to 0.3, "filterCutoff" to 9000.0, "compression" to 0.4),
            spatialMode = "binaural", spatialWidth = 0.75
        )

        val MEDITATION_MUSIC = MusicalPreset(
            name = "Meditation Music",
            description = "Peaceful soundscapes for deep meditation",
            category = "Wellness",
            bpm = 0.0, key = "A", scale = "Pentatonic", timeSignature = "free",
            effects = mapOf("reverbDecay" to 8.0, "reverbMix" to 0.7, "filterCutoff" to 2000.0, "shimmerReverb" to 0.5),
            spatialMode = "ambisonics", spatialWidth = 1.0
        )

        val ALL = listOf(
            AMBIENT_DRONE, TECHNO_MINIMAL, CHILL_HOP, NEO_CLASSICAL, SPACE_AMBIENT,
            TRIBAL_RHYTHM, CINEMATIC_EPIC, DARK_WAVE, JAZZ_FUSION, MEDITATION_MUSIC
        )
    }
}

// MARK: - Visual Presets

data class VisualPreset(
    override val id: String = UUID.randomUUID().toString(),
    override val name: String,
    override val description: String,
    override val category: String,
    override val author: String = "Echoelmusic",
    override val version: String = "1.0",
    val visualMode: String,
    val colorPalette: String,
    val motionSpeed: Double,
    val complexity: Double,
    val bioReactivity: Double,
    val parameters: Map<String, Double>
) : EnginePreset {
    companion object {
        val SACRED_MANDALA = VisualPreset(
            name = "Sacred Mandala",
            description = "Intricate rotating mandala patterns with sacred geometry",
            category = "Sacred Geometry",
            visualMode = "mandala", colorPalette = "golden", motionSpeed = 0.3,
            complexity = 0.8, bioReactivity = 0.9,
            parameters = mapOf("symmetry" to 12.0, "layers" to 5.0, "glow" to 0.7)
        )

        val COSMIC_NEBULA = VisualPreset(
            name = "Cosmic Nebula",
            description = "Deep space nebula simulation with flowing gas clouds",
            category = "Space",
            visualMode = "nebula", colorPalette = "cosmic", motionSpeed = 0.2,
            complexity = 0.9, bioReactivity = 0.6,
            parameters = mapOf("density" to 0.7, "turbulence" to 0.5, "stars" to 0.8)
        )

        val QUANTUM_FIELD = VisualPreset(
            name = "Quantum Field",
            description = "Abstract quantum particle interactions and wave functions",
            category = "Quantum",
            visualMode = "quantum", colorPalette = "quantum", motionSpeed = 0.5,
            complexity = 0.95, bioReactivity = 0.95,
            parameters = mapOf("particles" to 500.0, "entanglement" to 0.8, "coherence" to 0.9)
        )

        val FRACTAL_JOURNEY = VisualPreset(
            name = "Fractal Journey",
            description = "Infinite zoom into Mandelbrot set fractals",
            category = "Fractal",
            visualMode = "fractal", colorPalette = "rainbow", motionSpeed = 0.4,
            complexity = 1.0, bioReactivity = 0.7,
            parameters = mapOf("iterations" to 1000.0, "zoom" to 0.0001, "rotation" to 0.1)
        )

        val AURORA_BOREALIS = VisualPreset(
            name = "Aurora Borealis",
            description = "Northern lights dancing across the sky",
            category = "Nature",
            visualMode = "aurora", colorPalette = "aurora", motionSpeed = 0.35,
            complexity = 0.6, bioReactivity = 0.8,
            parameters = mapOf("waves" to 8.0, "shimmer" to 0.7, "height" to 0.9)
        )

        val GEOMETRIC_FLOW = VisualPreset(
            name = "Geometric Flow",
            description = "Flowing geometric shapes morphing and evolving",
            category = "Abstract",
            visualMode = "geometric", colorPalette = "minimal", motionSpeed = 0.4,
            complexity = 0.5, bioReactivity = 0.75,
            parameters = mapOf("shapes" to 20.0, "morphSpeed" to 0.3, "lineWidth" to 2.0)
        )

        val PARTICLE_STORM = VisualPreset(
            name = "Particle Storm",
            description = "Millions of particles reacting to music and bio signals",
            category = "Particles",
            visualMode = "particles", colorPalette = "fire", motionSpeed = 0.8,
            complexity = 0.85, bioReactivity = 1.0,
            parameters = mapOf("count" to 100000.0, "size" to 2.0, "force" to 0.5)
        )

        val WATER_MEDITATION = VisualPreset(
            name = "Water Meditation",
            description = "Calm water ripples and reflections",
            category = "Nature",
            visualMode = "water", colorPalette = "ocean", motionSpeed = 0.2,
            complexity = 0.4, bioReactivity = 0.85,
            parameters = mapOf("ripples" to 5.0, "clarity" to 0.8, "depth" to 0.6)
        )

        val NEURAL_NETWORK = VisualPreset(
            name = "Neural Network",
            description = "Synaptic connections firing in a brain-like network",
            category = "Science",
            visualMode = "neural", colorPalette = "electric", motionSpeed = 0.6,
            complexity = 0.9, bioReactivity = 0.9,
            parameters = mapOf("nodes" to 200.0, "connections" to 0.4, "pulseRate" to 0.5)
        )

        val LIGHT_TUNNEL = VisualPreset(
            name = "Light Tunnel",
            description = "Journey through an infinite tunnel of light",
            category = "Abstract",
            visualMode = "tunnel", colorPalette = "spectrum", motionSpeed = 0.5,
            complexity = 0.6, bioReactivity = 0.7,
            parameters = mapOf("segments" to 32.0, "twist" to 0.3, "brightness" to 0.9)
        )

        val ALL = listOf(
            SACRED_MANDALA, COSMIC_NEBULA, QUANTUM_FIELD, FRACTAL_JOURNEY, AURORA_BOREALIS,
            GEOMETRIC_FLOW, PARTICLE_STORM, WATER_MEDITATION, NEURAL_NETWORK, LIGHT_TUNNEL
        )
    }
}

// MARK: - Lighting Presets

data class LightingPreset(
    override val id: String = UUID.randomUUID().toString(),
    override val name: String,
    override val description: String,
    override val category: String,
    override val author: String = "Echoelmusic",
    override val version: String = "1.0",
    val colorScheme: String,
    val intensity: Double,
    val transitionSpeed: Double,
    val strobeEnabled: Boolean,
    val dmxChannels: Map<String, Int>,
    val bioReactivity: Double
) : EnginePreset {
    companion object {
        val SUNRISE_MEDITATION = LightingPreset(
            name = "Sunrise Meditation",
            description = "Gentle warm light simulating sunrise",
            category = "Wellness",
            colorScheme = "sunrise", intensity = 0.4, transitionSpeed = 0.1,
            strobeEnabled = false, dmxChannels = mapOf("red" to 255, "green" to 100, "blue" to 50),
            bioReactivity = 0.8
        )

        val RAVE_STROBE = LightingPreset(
            name = "Rave Strobe",
            description = "High-energy strobe effects for EDM",
            category = "Performance",
            colorScheme = "rave", intensity = 1.0, transitionSpeed = 1.0,
            strobeEnabled = true, dmxChannels = mapOf("red" to 255, "green" to 255, "blue" to 255),
            bioReactivity = 0.3
        )

        val LASER_SHOW = LightingPreset(
            name = "Laser Show",
            description = "Professional laser patterns and beams",
            category = "Performance",
            colorScheme = "laser", intensity = 0.9, transitionSpeed = 0.8,
            strobeEnabled = false, dmxChannels = mapOf("red" to 0, "green" to 255, "blue" to 0),
            bioReactivity = 0.5
        )

        val CANDLELIGHT = LightingPreset(
            name = "Candlelight",
            description = "Soft flickering candlelight ambiance",
            category = "Ambient",
            colorScheme = "candle", intensity = 0.3, transitionSpeed = 0.15,
            strobeEnabled = false, dmxChannels = mapOf("red" to 255, "green" to 140, "blue" to 20),
            bioReactivity = 0.6
        )

        val AURORA = LightingPreset(
            name = "Aurora",
            description = "Northern lights color patterns",
            category = "Ambient",
            colorScheme = "aurora", intensity = 0.5, transitionSpeed = 0.2,
            strobeEnabled = false, dmxChannels = mapOf("red" to 50, "green" to 200, "blue" to 100),
            bioReactivity = 0.85
        )

        val BIOFEEDBACK_GLOW = LightingPreset(
            name = "Biofeedback Glow",
            description = "Light color changes based on HRV coherence",
            category = "Wellness",
            colorScheme = "coherence", intensity = 0.6, transitionSpeed = 0.3,
            strobeEnabled = false, dmxChannels = mapOf("red" to 100, "green" to 200, "blue" to 150),
            bioReactivity = 1.0
        )

        val CLUB_RGB = LightingPreset(
            name = "Club RGB",
            description = "Classic nightclub RGB wash lights",
            category = "Performance",
            colorScheme = "rgb", intensity = 0.8, transitionSpeed = 0.6,
            strobeEnabled = false, dmxChannels = mapOf("red" to 255, "green" to 0, "blue" to 255),
            bioReactivity = 0.4
        )

        val MOONLIGHT = LightingPreset(
            name = "Moonlight",
            description = "Cool blue moonlight for sleep preparation",
            category = "Sleep",
            colorScheme = "moon", intensity = 0.15, transitionSpeed = 0.05,
            strobeEnabled = false, dmxChannels = mapOf("red" to 30, "green" to 50, "blue" to 80),
            bioReactivity = 0.7
        )

        val FIRE_DANCE = LightingPreset(
            name = "Fire Dance",
            description = "Dynamic fire-like color movements",
            category = "Performance",
            colorScheme = "fire", intensity = 0.7, transitionSpeed = 0.5,
            strobeEnabled = false, dmxChannels = mapOf("red" to 255, "green" to 80, "blue" to 0),
            bioReactivity = 0.6
        )

        val QUANTUM_PULSE = LightingPreset(
            name = "Quantum Pulse",
            description = "Pulsing quantum-inspired light patterns",
            category = "Quantum",
            colorScheme = "quantum", intensity = 0.5, transitionSpeed = 0.4,
            strobeEnabled = false, dmxChannels = mapOf("red" to 100, "green" to 50, "blue" to 200),
            bioReactivity = 0.95
        )

        val ALL = listOf(
            SUNRISE_MEDITATION, RAVE_STROBE, LASER_SHOW, CANDLELIGHT, AURORA,
            BIOFEEDBACK_GLOW, CLUB_RGB, MOONLIGHT, FIRE_DANCE, QUANTUM_PULSE
        )
    }
}

// MARK: - Streaming Presets

data class StreamingPreset(
    override val id: String = UUID.randomUUID().toString(),
    override val name: String,
    override val description: String,
    override val category: String,
    override val author: String = "Echoelmusic",
    override val version: String = "1.0",
    val resolution: String,
    val fps: Int,
    val bitrate: Int,
    val codec: String,
    val platform: String
) : EnginePreset {
    companion object {
        val YOUTUBE_4K = StreamingPreset(
            name = "YouTube Premium 4K",
            description = "Ultra-high quality YouTube streaming",
            category = "Professional",
            resolution = "3840x2160", fps = 60, bitrate = 40000, codec = "h264", platform = "youtube"
        )

        val TWITCH_LOW_LATENCY = StreamingPreset(
            name = "Twitch Low Latency",
            description = "Optimized for Twitch interactive streaming",
            category = "Gaming",
            resolution = "1920x1080", fps = 60, bitrate = 6000, codec = "h264", platform = "twitch"
        )

        val INSTAGRAM_LIVE = StreamingPreset(
            name = "Instagram Live",
            description = "Mobile-optimized Instagram streaming",
            category = "Social",
            resolution = "1080x1920", fps = 30, bitrate = 4000, codec = "h264", platform = "instagram"
        )

        val TIKTOK_LIVE = StreamingPreset(
            name = "TikTok Live",
            description = "Vertical format for TikTok",
            category = "Social",
            resolution = "1080x1920", fps = 30, bitrate = 3500, codec = "h264", platform = "tiktok"
        )

        val FACEBOOK_LIVE = StreamingPreset(
            name = "Facebook Live",
            description = "Facebook Live broadcast quality",
            category = "Social",
            resolution = "1920x1080", fps = 30, bitrate = 4500, codec = "h264", platform = "facebook"
        )

        val ALL = listOf(YOUTUBE_4K, TWITCH_LOW_LATENCY, INSTAGRAM_LIVE, TIKTOK_LIVE, FACEBOOK_LIVE)
    }
}

// MARK: - Collaboration Presets

data class CollaborationPreset(
    override val id: String = UUID.randomUUID().toString(),
    override val name: String,
    override val description: String,
    override val category: String,
    override val author: String = "Echoelmusic",
    override val version: String = "1.0",
    val maxParticipants: Int,
    val syncMode: String,
    val audioQuality: String,
    val features: List<String>
) : EnginePreset {
    companion object {
        val VIRTUAL_CONCERT = CollaborationPreset(
            name = "Virtual Concert",
            description = "Large-scale virtual concert experience",
            category = "Performance",
            maxParticipants = 10000, syncMode = "broadcast", audioQuality = "high",
            features = listOf("stage", "audience", "reactions", "chat")
        )

        val WELLNESS_CIRCLE = CollaborationPreset(
            name = "Wellness Circle",
            description = "Intimate group meditation session",
            category = "Wellness",
            maxParticipants = 50, syncMode = "coherence", audioQuality = "medium",
            features = listOf("coherence_sync", "breathing_guide", "visualization")
        )

        val MUSIC_JAM = CollaborationPreset(
            name = "Music Jam",
            description = "Low-latency music collaboration",
            category = "Music",
            maxParticipants = 8, syncMode = "low_latency", audioQuality = "professional",
            features = listOf("midi_sync", "audio_mix", "loop_share")
        )

        val RESEARCH_LAB = CollaborationPreset(
            name = "Research Lab",
            description = "Scientific research collaboration",
            category = "Research",
            maxParticipants = 100, syncMode = "data", audioQuality = "medium",
            features = listOf("data_collection", "analysis", "export")
        )

        val CREATIVE_STUDIO = CollaborationPreset(
            name = "Creative Studio",
            description = "Collaborative creative workspace",
            category = "Creative",
            maxParticipants = 20, syncMode = "shared_canvas", audioQuality = "high",
            features = listOf("shared_visuals", "audio_collab", "version_control")
        )

        val ALL = listOf(VIRTUAL_CONCERT, WELLNESS_CIRCLE, MUSIC_JAM, RESEARCH_LAB, CREATIVE_STUDIO)
    }
}

// MARK: - Presets Manager

class PresetsManager {

    companion object {
        private const val TAG = "PresetsManager"
    }

    // All Presets
    private val _bioReactivePresets = MutableStateFlow(BioReactivePreset.ALL)
    val bioReactivePresets: StateFlow<List<BioReactivePreset>> = _bioReactivePresets

    private val _musicalPresets = MutableStateFlow(MusicalPreset.ALL)
    val musicalPresets: StateFlow<List<MusicalPreset>> = _musicalPresets

    private val _visualPresets = MutableStateFlow(VisualPreset.ALL)
    val visualPresets: StateFlow<List<VisualPreset>> = _visualPresets

    private val _lightingPresets = MutableStateFlow(LightingPreset.ALL)
    val lightingPresets: StateFlow<List<LightingPreset>> = _lightingPresets

    private val _streamingPresets = MutableStateFlow(StreamingPreset.ALL)
    val streamingPresets: StateFlow<List<StreamingPreset>> = _streamingPresets

    private val _collaborationPresets = MutableStateFlow(CollaborationPreset.ALL)
    val collaborationPresets: StateFlow<List<CollaborationPreset>> = _collaborationPresets

    // User custom presets
    private val _userPresets = MutableStateFlow<List<EnginePreset>>(emptyList())
    val userPresets: StateFlow<List<EnginePreset>> = _userPresets

    init {
        Log.i(TAG, "Presets Manager initialized with ${getTotalPresetCount()} presets")
    }

    fun getTotalPresetCount(): Int {
        return _bioReactivePresets.value.size +
                _musicalPresets.value.size +
                _visualPresets.value.size +
                _lightingPresets.value.size +
                _streamingPresets.value.size +
                _collaborationPresets.value.size +
                _userPresets.value.size
    }

    fun getAllPresets(): List<EnginePreset> {
        return _bioReactivePresets.value +
                _musicalPresets.value +
                _visualPresets.value +
                _lightingPresets.value +
                _streamingPresets.value +
                _collaborationPresets.value +
                _userPresets.value
    }

    fun getPresetsByCategory(category: String): List<EnginePreset> {
        return getAllPresets().filter { it.category == category }
    }

    fun searchPresets(query: String): List<EnginePreset> {
        val lowerQuery = query.lowercase()
        return getAllPresets().filter {
            it.name.lowercase().contains(lowerQuery) ||
            it.description.lowercase().contains(lowerQuery) ||
            it.category.lowercase().contains(lowerQuery)
        }
    }

    fun getBioReactivePreset(name: String): BioReactivePreset? {
        return _bioReactivePresets.value.find { it.name == name }
    }

    fun getMusicalPreset(name: String): MusicalPreset? {
        return _musicalPresets.value.find { it.name == name }
    }

    fun getVisualPreset(name: String): VisualPreset? {
        return _visualPresets.value.find { it.name == name }
    }

    fun getLightingPreset(name: String): LightingPreset? {
        return _lightingPresets.value.find { it.name == name }
    }

    // Categories
    fun getAllCategories(): List<String> {
        return getAllPresets().map { it.category }.distinct().sorted()
    }
}
