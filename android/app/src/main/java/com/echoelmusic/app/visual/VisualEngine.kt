package com.echoelmusic.app.visual

import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.*
import kotlin.math.*

/**
 * Echoelmusic Visual Engine for Android
 * Immersive visualization with 30+ modes and bio-reactive modulation
 *
 * Features:
 * - 30+ visual modes (sacred geometry, fractals, particles, quantum)
 * - Bio-reactive modulation (HRV, coherence, breathing)
 * - Multi-layer composition with blend modes
 * - Real-time parameter control
 * - 6D visualization dimensions
 * - 8 projection modes
 *
 * Port of iOS ImmersiveVisualEngine with OpenGL ES / Compose Canvas
 */

// MARK: - Visual Mode

enum class VisualMode(val displayName: String, val category: VisualCategory) {
    // Sacred Geometry
    FLOWER_OF_LIFE("Flower of Life", VisualCategory.SACRED_GEOMETRY),
    METATRONS_CUBE("Metatron's Cube", VisualCategory.SACRED_GEOMETRY),
    SRI_YANTRA("Sri Yantra", VisualCategory.SACRED_GEOMETRY),
    TORUS("Torus", VisualCategory.SACRED_GEOMETRY),
    SEED_OF_LIFE("Seed of Life", VisualCategory.SACRED_GEOMETRY),
    GOLDEN_SPIRAL("Golden Spiral", VisualCategory.SACRED_GEOMETRY),

    // Fractals
    MANDELBROT("Mandelbrot Set", VisualCategory.FRACTAL),
    JULIA("Julia Set", VisualCategory.FRACTAL),
    BURNING_SHIP("Burning Ship", VisualCategory.FRACTAL),
    SIERPINSKI("Sierpinski Triangle", VisualCategory.FRACTAL),
    DRAGON_CURVE("Dragon Curve", VisualCategory.FRACTAL),
    BARNSLEY_FERN("Barnsley Fern", VisualCategory.FRACTAL),

    // Particles
    PARTICLE_FLOW("Particle Flow", VisualCategory.PARTICLES),
    PARTICLE_STORM("Particle Storm", VisualCategory.PARTICLES),
    PARTICLE_LIFE("Particle Life", VisualCategory.PARTICLES),
    FLOCKING("Flocking Simulation", VisualCategory.PARTICLES),

    // Quantum
    QUANTUM_WAVE("Quantum Wave", VisualCategory.QUANTUM),
    QUANTUM_FIELD("Quantum Field", VisualCategory.QUANTUM),
    QUANTUM_TUNNEL("Quantum Tunnel", VisualCategory.QUANTUM),
    ENTANGLEMENT("Entanglement", VisualCategory.QUANTUM),

    // Nature
    AURORA_BOREALIS("Aurora Borealis", VisualCategory.NATURE),
    WATER_RIPPLES("Water Ripples", VisualCategory.NATURE),
    COSMIC_NEBULA("Cosmic Nebula", VisualCategory.NATURE),
    GALAXY_SPIRAL("Galaxy Spiral", VisualCategory.NATURE),

    // Abstract
    KALEIDOSCOPE("Kaleidoscope", VisualCategory.ABSTRACT),
    WAVEFORM("Waveform", VisualCategory.ABSTRACT),
    SPECTRUM("Spectrum Analyzer", VisualCategory.ABSTRACT),
    NEURAL_NETWORK("Neural Network", VisualCategory.ABSTRACT),
    LIGHT_TUNNEL("Light Tunnel", VisualCategory.ABSTRACT),
    GEOMETRIC_FLOW("Geometric Flow", VisualCategory.ABSTRACT)
}

enum class VisualCategory(val displayName: String) {
    SACRED_GEOMETRY("Sacred Geometry"),
    FRACTAL("Fractal"),
    PARTICLES("Particles"),
    QUANTUM("Quantum"),
    NATURE("Nature"),
    ABSTRACT("Abstract")
}

// MARK: - Projection Mode

enum class ProjectionMode(val displayName: String) {
    STANDARD_2D("Standard 2D"),
    EQUIRECTANGULAR("Equirectangular 360°"),
    CUBEMAP("Cubemap"),
    FISHEYE("Fisheye"),
    DOMEMASTER("Domemaster"),
    CYLINDRICAL("Cylindrical"),
    STEREOSCOPIC("Stereoscopic 3D"),
    HOLOGRAPHIC("Holographic")
}

// MARK: - Visual Dimension

enum class VisualDimension(val displayName: String) {
    D2("2D Standard"),
    D3("3D Spatial"),
    D4_TEMPORAL("4D Temporal"),
    D5_QUANTUM("5D Quantum"),
    D6_BIO_COHERENCE("6D Bio-Coherence Manifold")
}

// MARK: - Blend Mode

enum class BlendMode(val displayName: String) {
    NORMAL("Normal"),
    ADD("Add"),
    MULTIPLY("Multiply"),
    SCREEN("Screen"),
    OVERLAY("Overlay"),
    SOFT_LIGHT("Soft Light"),
    HARD_LIGHT("Hard Light"),
    COLOR_DODGE("Color Dodge"),
    COLOR_BURN("Color Burn"),
    DIFFERENCE("Difference"),
    EXCLUSION("Exclusion"),
    HUE("Hue"),
    SATURATION("Saturation"),
    COLOR("Color"),
    LUMINOSITY("Luminosity"),
    QUANTUM_BLEND("Quantum Blend"),
    BIO_COHERENT("Bio-Coherent"),
    TEMPORAL_FADE("Temporal Fade"),
    HEART_PULSE("Heart Pulse")
}

// MARK: - Color Palette

enum class ColorPalette(val displayName: String, val colors: List<Long>) {
    QUANTUM(
        "Quantum",
        listOf(0xFF6B5B95, 0xFF88B04B, 0xFFF7CAC9, 0xFF92A8D1, 0xFF955251)
    ),
    COSMIC(
        "Cosmic",
        listOf(0xFF0D1B2A, 0xFF1B263B, 0xFF415A77, 0xFF778DA9, 0xFFE0E1DD)
    ),
    AURORA(
        "Aurora",
        listOf(0xFF00FF87, 0xFF60EFFF, 0xFFFF9A00, 0xFFFF00E4, 0xFF00FF87)
    ),
    FIRE(
        "Fire",
        listOf(0xFFFF0000, 0xFFFF6600, 0xFFFFCC00, 0xFFFFFF00, 0xFFFF0000)
    ),
    OCEAN(
        "Ocean",
        listOf(0xFF006994, 0xFF00B4D8, 0xFF90E0EF, 0xFFCAF0F8, 0xFF006994)
    ),
    FOREST(
        "Forest",
        listOf(0xFF2D6A4F, 0xFF40916C, 0xFF52B788, 0xFF74C69D, 0xFF95D5B2)
    ),
    SUNSET(
        "Sunset",
        listOf(0xFFFF6B6B, 0xFFFECA57, 0xFFFF9FF3, 0xFF54A0FF, 0xFF5F27CD)
    ),
    GOLDEN(
        "Golden",
        listOf(0xFFFFD700, 0xFFFFA500, 0xFFB8860B, 0xFFDAA520, 0xFFFFD700)
    ),
    MINIMAL(
        "Minimal",
        listOf(0xFFFFFFFF, 0xFFE0E0E0, 0xFF808080, 0xFF404040, 0xFF000000)
    ),
    RAINBOW(
        "Rainbow",
        listOf(0xFFFF0000, 0xFFFF7F00, 0xFFFFFF00, 0xFF00FF00, 0xFF0000FF, 0xFF8B00FF)
    ),
    SPECTRUM(
        "Spectrum",
        listOf(0xFFFF0080, 0xFF8000FF, 0xFF0080FF, 0xFF00FF80, 0xFFFFFF00)
    ),
    ELECTRIC(
        "Electric",
        listOf(0xFF00FFFF, 0xFFFF00FF, 0xFFFFFF00, 0xFF00FF00, 0xFF0000FF)
    )
}

// MARK: - Visual Layer

data class VisualLayer(
    val id: String = UUID.randomUUID().toString(),
    var mode: VisualMode,
    var opacity: Float = 1.0f,
    var blendMode: BlendMode = BlendMode.NORMAL,
    var isVisible: Boolean = true,
    var colorPalette: ColorPalette = ColorPalette.QUANTUM,
    var parameters: MutableMap<String, Float> = mutableMapOf()
)

// MARK: - Bio-Reactive Mapping

data class BioReactiveMapping(
    val source: BioSource,
    val target: VisualTarget,
    val curve: MappingCurve = MappingCurve.LINEAR,
    val intensity: Float = 1.0f,
    val min: Float = 0f,
    val max: Float = 1f
)

enum class BioSource(val displayName: String) {
    HEART_RATE("Heart Rate"),
    HRV("HRV"),
    COHERENCE("Coherence"),
    BREATHING_RATE("Breathing Rate"),
    BREATH_PHASE("Breath Phase"),
    GSR("GSR"),
    TEMPERATURE("Temperature"),
    SPO2("SpO2")
}

enum class VisualTarget(val displayName: String) {
    BRIGHTNESS("Brightness"),
    SATURATION("Saturation"),
    HUE("Hue"),
    SPEED("Speed"),
    COMPLEXITY("Complexity"),
    SCALE("Scale"),
    ROTATION("Rotation"),
    PARTICLE_COUNT("Particle Count"),
    PARTICLE_SIZE("Particle Size"),
    GLOW("Glow"),
    BLUR("Blur"),
    DISTORTION("Distortion")
}

enum class MappingCurve(val displayName: String) {
    LINEAR("Linear"),
    EXPONENTIAL("Exponential"),
    LOGARITHMIC("Logarithmic"),
    S_CURVE("S-Curve"),
    SINE("Sine"),
    STEPPED("Stepped")
}

// MARK: - Visual State

data class VisualState(
    val mode: VisualMode = VisualMode.FLOWER_OF_LIFE,
    val dimension: VisualDimension = VisualDimension.D2,
    val projection: ProjectionMode = ProjectionMode.STANDARD_2D,
    val brightness: Float = 0.8f,
    val saturation: Float = 0.7f,
    val speed: Float = 0.5f,
    val complexity: Float = 0.6f,
    val scale: Float = 1.0f,
    val rotation: Float = 0f,
    val glow: Float = 0.3f,
    val colorPalette: ColorPalette = ColorPalette.QUANTUM
)

// MARK: - Visual Engine

class VisualEngine {

    companion object {
        private const val TAG = "VisualEngine"
        private const val RENDER_FPS = 60
        private const val RENDER_INTERVAL_MS = 1000L / RENDER_FPS
    }

    // State
    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private val _currentState = MutableStateFlow(VisualState())
    val currentState: StateFlow<VisualState> = _currentState

    private val _layers = MutableStateFlow<List<VisualLayer>>(emptyList())
    val layers: StateFlow<List<VisualLayer>> = _layers

    private val _fps = MutableStateFlow(0f)
    val fps: StateFlow<Float> = _fps

    private val _frameCount = MutableStateFlow(0L)
    val frameCount: StateFlow<Long> = _frameCount

    // Bio-Reactive
    private val _bioMappings = MutableStateFlow<List<BioReactiveMapping>>(emptyList())
    val bioMappings: StateFlow<List<BioReactiveMapping>> = _bioMappings

    private val _bioReactivityEnabled = MutableStateFlow(true)
    val bioReactivityEnabled: StateFlow<Boolean> = _bioReactivityEnabled

    // Bio data inputs
    private var currentCoherence = 0.5f
    private var currentHeartRate = 70f
    private var currentBreathPhase = 0f

    // Processing
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var renderJob: Job? = null
    private var lastFrameTime = 0L

    init {
        setupDefaultLayers()
        Log.i(TAG, "Visual Engine initialized with ${VisualMode.values().size} modes")
    }

    private fun setupDefaultLayers() {
        _layers.value = listOf(
            VisualLayer(
                mode = VisualMode.FLOWER_OF_LIFE,
                opacity = 1.0f,
                blendMode = BlendMode.NORMAL
            )
        )
    }

    // MARK: - Lifecycle

    fun start() {
        if (_isRunning.value) return

        _isRunning.value = true
        startRenderLoop()
        Log.i(TAG, "Visual Engine started")
    }

    fun stop() {
        _isRunning.value = false
        renderJob?.cancel()
        Log.i(TAG, "Visual Engine stopped")
    }

    fun shutdown() {
        stop()
        scope.cancel()
        Log.i(TAG, "Visual Engine shutdown")
    }

    private fun startRenderLoop() {
        renderJob?.cancel()
        renderJob = scope.launch {
            lastFrameTime = System.currentTimeMillis()

            while (_isRunning.value && isActive) {
                val currentTime = System.currentTimeMillis()
                val deltaTime = (currentTime - lastFrameTime) / 1000f

                // Update FPS
                if (deltaTime > 0) {
                    _fps.value = 1f / deltaTime
                }

                // Render frame
                renderFrame(deltaTime)

                // Increment frame count
                _frameCount.value++
                lastFrameTime = currentTime

                // Wait for next frame
                delay(RENDER_INTERVAL_MS)
            }
        }
    }

    private fun renderFrame(deltaTime: Float) {
        // Apply bio-reactive modulation
        if (_bioReactivityEnabled.value) {
            applyBioModulation()
        }

        // Update state based on time
        val state = _currentState.value
        val newRotation = (state.rotation + state.speed * deltaTime * 10f) % 360f
        _currentState.value = state.copy(rotation = newRotation)

        // Update each layer
        _layers.value = _layers.value.map { layer ->
            updateLayer(layer, deltaTime)
        }
    }

    private fun updateLayer(layer: VisualLayer, deltaTime: Float): VisualLayer {
        // Layer-specific updates based on mode
        val params = layer.parameters.toMutableMap()

        when (layer.mode) {
            VisualMode.PARTICLE_FLOW, VisualMode.PARTICLE_STORM -> {
                params["time"] = (params["time"] ?: 0f) + deltaTime
            }
            VisualMode.QUANTUM_WAVE -> {
                params["phase"] = ((params["phase"] ?: 0f) + deltaTime * 2f) % (2f * PI.toFloat())
            }
            else -> {}
        }

        return layer.copy(parameters = params)
    }

    // MARK: - Mode Control

    fun setMode(mode: VisualMode) {
        _currentState.value = _currentState.value.copy(mode = mode)
        Log.d(TAG, "Visual mode set to ${mode.displayName}")
    }

    fun setDimension(dimension: VisualDimension) {
        _currentState.value = _currentState.value.copy(dimension = dimension)
    }

    fun setProjection(projection: ProjectionMode) {
        _currentState.value = _currentState.value.copy(projection = projection)
    }

    fun setColorPalette(palette: ColorPalette) {
        _currentState.value = _currentState.value.copy(colorPalette = palette)
    }

    // MARK: - Parameter Control

    fun setBrightness(brightness: Float) {
        _currentState.value = _currentState.value.copy(brightness = brightness.coerceIn(0f, 1f))
    }

    fun setSaturation(saturation: Float) {
        _currentState.value = _currentState.value.copy(saturation = saturation.coerceIn(0f, 1f))
    }

    fun setSpeed(speed: Float) {
        _currentState.value = _currentState.value.copy(speed = speed.coerceIn(0f, 2f))
    }

    fun setComplexity(complexity: Float) {
        _currentState.value = _currentState.value.copy(complexity = complexity.coerceIn(0f, 1f))
    }

    fun setScale(scale: Float) {
        _currentState.value = _currentState.value.copy(scale = scale.coerceIn(0.1f, 10f))
    }

    fun setGlow(glow: Float) {
        _currentState.value = _currentState.value.copy(glow = glow.coerceIn(0f, 1f))
    }

    // MARK: - Layer Management

    fun addLayer(mode: VisualMode, blendMode: BlendMode = BlendMode.ADD): VisualLayer {
        val layer = VisualLayer(mode = mode, blendMode = blendMode)
        _layers.value = _layers.value + layer
        return layer
    }

    fun removeLayer(layerId: String) {
        _layers.value = _layers.value.filter { it.id != layerId }
    }

    fun setLayerOpacity(layerId: String, opacity: Float) {
        _layers.value = _layers.value.map { layer ->
            if (layer.id == layerId) {
                layer.copy(opacity = opacity.coerceIn(0f, 1f))
            } else {
                layer
            }
        }
    }

    fun setLayerBlendMode(layerId: String, blendMode: BlendMode) {
        _layers.value = _layers.value.map { layer ->
            if (layer.id == layerId) {
                layer.copy(blendMode = blendMode)
            } else {
                layer
            }
        }
    }

    fun setLayerVisibility(layerId: String, isVisible: Boolean) {
        _layers.value = _layers.value.map { layer ->
            if (layer.id == layerId) {
                layer.copy(isVisible = isVisible)
            } else {
                layer
            }
        }
    }

    fun reorderLayers(fromIndex: Int, toIndex: Int) {
        val mutableLayers = _layers.value.toMutableList()
        if (fromIndex in mutableLayers.indices && toIndex in mutableLayers.indices) {
            val layer = mutableLayers.removeAt(fromIndex)
            mutableLayers.add(toIndex, layer)
            _layers.value = mutableLayers
        }
    }

    // MARK: - Bio-Reactive Modulation

    fun enableBioReactivity(enabled: Boolean) {
        _bioReactivityEnabled.value = enabled
    }

    fun addBioMapping(mapping: BioReactiveMapping) {
        _bioMappings.value = _bioMappings.value + mapping
    }

    fun removeBioMapping(source: BioSource, target: VisualTarget) {
        _bioMappings.value = _bioMappings.value.filter {
            !(it.source == source && it.target == target)
        }
    }

    fun clearBioMappings() {
        _bioMappings.value = emptyList()
    }

    fun updateBioData(coherence: Float, heartRate: Float, breathPhase: Float) {
        currentCoherence = coherence
        currentHeartRate = heartRate
        currentBreathPhase = breathPhase
    }

    private fun applyBioModulation() {
        var state = _currentState.value

        for (mapping in _bioMappings.value) {
            val sourceValue = when (mapping.source) {
                BioSource.COHERENCE -> currentCoherence
                BioSource.HEART_RATE -> (currentHeartRate - 40f) / 160f // Normalize 40-200 to 0-1
                BioSource.BREATH_PHASE -> currentBreathPhase
                else -> 0.5f
            }

            val mappedValue = applyMappingCurve(sourceValue, mapping.curve)
            val scaledValue = mapping.min + (mapping.max - mapping.min) * mappedValue * mapping.intensity

            state = when (mapping.target) {
                VisualTarget.BRIGHTNESS -> state.copy(brightness = scaledValue.coerceIn(0f, 1f))
                VisualTarget.SATURATION -> state.copy(saturation = scaledValue.coerceIn(0f, 1f))
                VisualTarget.SPEED -> state.copy(speed = scaledValue.coerceIn(0f, 2f))
                VisualTarget.COMPLEXITY -> state.copy(complexity = scaledValue.coerceIn(0f, 1f))
                VisualTarget.SCALE -> state.copy(scale = scaledValue.coerceIn(0.1f, 10f))
                VisualTarget.GLOW -> state.copy(glow = scaledValue.coerceIn(0f, 1f))
                else -> state
            }
        }

        _currentState.value = state
    }

    private fun applyMappingCurve(value: Float, curve: MappingCurve): Float {
        return when (curve) {
            MappingCurve.LINEAR -> value
            MappingCurve.EXPONENTIAL -> value * value
            MappingCurve.LOGARITHMIC -> if (value > 0) ln(1 + value * 9) / ln(10f) else 0f
            MappingCurve.S_CURVE -> {
                val x = value * 2 - 1
                (tanh(x * 2) + 1) / 2
            }
            MappingCurve.SINE -> (sin(value * PI.toFloat() - PI.toFloat() / 2) + 1) / 2
            MappingCurve.STEPPED -> (value * 10).toInt() / 10f
        }
    }

    // MARK: - Presets

    fun applyPreset(preset: VisualPresetConfig) {
        _currentState.value = VisualState(
            mode = preset.mode,
            brightness = preset.brightness,
            saturation = preset.saturation,
            speed = preset.speed,
            complexity = preset.complexity,
            colorPalette = preset.colorPalette
        )

        // Setup bio mappings from preset
        _bioMappings.value = preset.bioMappings
    }

    // MARK: - Rendering Helpers (for Canvas/OpenGL integration)

    fun getFlowerOfLifePoints(radius: Float, centerX: Float, centerY: Float): List<Pair<Float, Float>> {
        val points = mutableListOf<Pair<Float, Float>>()
        val goldenAngle = PI.toFloat() / 3f // 60 degrees

        // Center circle
        points.add(Pair(centerX, centerY))

        // 6 surrounding circles
        for (i in 0 until 6) {
            val angle = goldenAngle * i
            val x = centerX + radius * cos(angle)
            val y = centerY + radius * sin(angle)
            points.add(Pair(x, y))
        }

        return points
    }

    fun getMandelbrotIterations(x: Double, y: Double, maxIterations: Int): Int {
        var zr = 0.0
        var zi = 0.0
        var iteration = 0

        while (zr * zr + zi * zi < 4.0 && iteration < maxIterations) {
            val temp = zr * zr - zi * zi + x
            zi = 2 * zr * zi + y
            zr = temp
            iteration++
        }

        return iteration
    }

    fun getJuliaIterations(x: Double, y: Double, cx: Double, cy: Double, maxIterations: Int): Int {
        var zr = x
        var zi = y
        var iteration = 0

        while (zr * zr + zi * zi < 4.0 && iteration < maxIterations) {
            val temp = zr * zr - zi * zi + cx
            zi = 2 * zr * zi + cy
            zr = temp
            iteration++
        }

        return iteration
    }

    fun getGoldenSpiralPoints(turns: Int, pointsPerTurn: Int): List<Pair<Float, Float>> {
        val points = mutableListOf<Pair<Float, Float>>()
        val goldenRatio = (1 + sqrt(5f)) / 2f
        val totalPoints = turns * pointsPerTurn

        for (i in 0 until totalPoints) {
            val theta = i * 2 * PI.toFloat() / pointsPerTurn
            val r = goldenRatio.pow(theta / (2 * PI.toFloat()))
            points.add(Pair(r * cos(theta), r * sin(theta)))
        }

        return points
    }
}

// MARK: - Visual Preset Config

data class VisualPresetConfig(
    val name: String,
    val mode: VisualMode,
    val brightness: Float = 0.8f,
    val saturation: Float = 0.7f,
    val speed: Float = 0.5f,
    val complexity: Float = 0.6f,
    val colorPalette: ColorPalette = ColorPalette.QUANTUM,
    val bioMappings: List<BioReactiveMapping> = emptyList()
) {
    companion object {
        val MEDITATION = VisualPresetConfig(
            name = "Meditation",
            mode = VisualMode.FLOWER_OF_LIFE,
            brightness = 0.4f,
            saturation = 0.5f,
            speed = 0.2f,
            complexity = 0.4f,
            colorPalette = ColorPalette.GOLDEN,
            bioMappings = listOf(
                BioReactiveMapping(BioSource.COHERENCE, VisualTarget.BRIGHTNESS),
                BioReactiveMapping(BioSource.BREATH_PHASE, VisualTarget.SCALE)
            )
        )

        val ENERGETIC = VisualPresetConfig(
            name = "Energetic",
            mode = VisualMode.PARTICLE_STORM,
            brightness = 0.9f,
            saturation = 0.9f,
            speed = 1.2f,
            complexity = 0.9f,
            colorPalette = ColorPalette.FIRE,
            bioMappings = listOf(
                BioReactiveMapping(BioSource.HEART_RATE, VisualTarget.SPEED),
                BioReactiveMapping(BioSource.COHERENCE, VisualTarget.COMPLEXITY)
            )
        )

        val COSMIC = VisualPresetConfig(
            name = "Cosmic",
            mode = VisualMode.COSMIC_NEBULA,
            brightness = 0.7f,
            saturation = 0.8f,
            speed = 0.3f,
            complexity = 0.7f,
            colorPalette = ColorPalette.COSMIC
        )

        val QUANTUM_MEDITATION = VisualPresetConfig(
            name = "Quantum Meditation",
            mode = VisualMode.QUANTUM_FIELD,
            brightness = 0.5f,
            saturation = 0.6f,
            speed = 0.4f,
            complexity = 0.8f,
            colorPalette = ColorPalette.QUANTUM,
            bioMappings = listOf(
                BioReactiveMapping(BioSource.COHERENCE, VisualTarget.GLOW, intensity = 1.0f),
                BioReactiveMapping(BioSource.BREATH_PHASE, VisualTarget.SCALE)
            )
        )

        val ALL = listOf(MEDITATION, ENERGETIC, COSMIC, QUANTUM_MEDITATION)
    }
}
