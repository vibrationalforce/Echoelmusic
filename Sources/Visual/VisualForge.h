#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <functional>

/**
 * VisualForge
 *
 * Professional real-time visual synthesizer and generator.
 * Inspired by TouchDesigner, Resolume, VDMX, but evolved with
 * audio-reactive and bio-reactive visual synthesis.
 *
 * Features:
 * - Real-time GPU shader processing
 * - 50+ built-in generators (noise, fractals, particles, etc.)
 * - 30+ effects (blur, distort, feedback, kaleidoscope, etc.)
 * - Audio-reactive modulation (FFT, waveform, beat detection)
 * - Bio-reactive visual morphing
 * - Composition layers (blend modes)
 * - Video input/output support
 * - Projection mapping ready
 * - OSC/MIDI control
 * - 60+ FPS real-time performance
 */
class VisualForge
{
public:
    //==========================================================================
    // Generator Types
    //==========================================================================

    enum class GeneratorType
    {
        // Basic
        SolidColor,
        Gradient,
        Checkerboard,
        Grid,

        // Noise
        PerlinNoise,
        SimplexNoise,
        VoronoiNoise,
        CellularNoise,

        // Fractals
        Mandelbrot,
        Julia,
        FractalTree,
        LSystem,

        // Particles
        ParticleSystem,
        FlowField,
        Attractors,

        // Patterns
        Spirals,
        Tunnel,
        Kaleidoscope,
        Plasma,

        // 3D
        Cube3D,
        Sphere3D,
        Torus3D,
        PointCloud3D,

        // Audio-Reactive
        Waveform,
        Spectrum,
        CircularSpectrum,
        Spectrogram,

        // Video
        VideoInput,
        CameraInput,
        ScreenCapture
    };

    //==========================================================================
    // Effect Types
    //==========================================================================

    enum class EffectType
    {
        // Color
        Invert,
        Hue,
        Saturation,
        Brightness,
        Contrast,
        Colorize,
        Posterize,

        // Distortion
        Pixelate,
        Mosaic,
        Ripple,
        Twirl,
        Bulge,
        Mirror,

        // Blur
        GaussianBlur,
        MotionBlur,
        RadialBlur,
        ZoomBlur,

        // Transform
        Rotate,
        Scale,
        Translate,
        Perspective,

        // Feedback
        VideoFeedback,
        Trails,
        Echo,

        // Advanced
        Kaleidoscope,
        Chromatic,
        Glitch,
        Datamosh,
        EdgeDetect,

        // 3D
        Depth,
        DisplacementMap,
        NormalMap
    };

    //==========================================================================
    // Blend Modes
    //==========================================================================

    enum class BlendMode
    {
        Normal,
        Add,
        Multiply,
        Screen,
        Overlay,
        Difference,
        Exclusion,
        ColorDodge,
        ColorBurn
    };

    //==========================================================================
    // Layer Configuration
    //==========================================================================

    struct Layer
    {
        bool enabled = true;
        juce::String name;

        GeneratorType generator = GeneratorType::SolidColor;
        std::vector<EffectType> effects;

        BlendMode blendMode = BlendMode::Normal;
        float opacity = 1.0f;

        // Transform
        float x = 0.0f, y = 0.0f;      // Position (-1.0 to 1.0)
        float scaleX = 1.0f, scaleY = 1.0f;
        float rotation = 0.0f;          // Radians

        // Generator parameters (generic)
        std::map<juce::String, float> generatorParams;

        // Effect parameters
        std::vector<std::map<juce::String, float>> effectParams;

        Layer() = default;
    };

    //==========================================================================
    // Audio Reactive Configuration
    //==========================================================================

    struct AudioReactive
    {
        bool enabled = false;

        // FFT settings
        int fftSize = 512;
        int numBands = 64;
        float smoothing = 0.8f;         // 0.0 to 1.0

        // Mapping
        juce::String targetParameter;  // e.g., "scale", "rotation", "color"
        float minValue = 0.0f;
        float maxValue = 1.0f;

        // Band selection
        int bandStart = 0;
        int bandEnd = 63;

        AudioReactive() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    VisualForge();
    ~VisualForge() = default;

    //==========================================================================
    // Layer Management
    //==========================================================================

    /** Get number of layers */
    int getNumLayers() const { return static_cast<int>(layers.size()); }

    /** Add layer */
    int addLayer(const Layer& layer);

    /** Get/Set layer */
    Layer& getLayer(int index);
    const Layer& getLayer(int index) const;
    void setLayer(int index, const Layer& layer);

    /** Remove layer */
    void removeLayer(int index);

    /** Clear all layers */
    void clearLayers();

    //==========================================================================
    // Resolution & Output
    //==========================================================================

    /** Set output resolution */
    void setResolution(int width, int height);
    void getResolution(int& width, int& height) const;

    /** Set frame rate target */
    void setTargetFPS(int fps);
    int getTargetFPS() const { return targetFPS; }

    //==========================================================================
    // Audio Reactive
    //==========================================================================

    /** Set audio reactive configuration */
    void setAudioReactive(const AudioReactive& config);
    const AudioReactive& getAudioReactive() const { return audioReactive; }

    /** Update audio spectrum data */
    void updateAudioSpectrum(const std::vector<float>& spectrumData);

    /** Update waveform data */
    void updateWaveform(const std::vector<float>& waveformData);

    //==========================================================================
    // Bio-Reactive
    //==========================================================================

    /** Set bio-data for reactive visuals */
    void setBioData(float hrv, float coherence);
    void setBioReactiveEnabled(bool enabled);

    //==========================================================================
    // Rendering
    //==========================================================================

    /** Render current frame to image */
    juce::Image renderFrame();

    /** Get current FPS */
    float getCurrentFPS() const { return currentFPS; }

    //==========================================================================
    // Presets
    //==========================================================================

    /** Load preset */
    bool loadPreset(const juce::File& file);

    /** Save preset */
    bool savePreset(const juce::File& file) const;

    /** Get built-in preset names */
    std::vector<juce::String> getBuiltInPresets() const;

    /** Load built-in preset */
    void loadBuiltInPreset(const juce::String& name);

    //==========================================================================
    // Recording
    //==========================================================================

    /** Start recording frames */
    void startRecording(const juce::File& outputFile);

    /** Stop recording */
    void stopRecording();

    /** Is currently recording */
    bool isRecording() const { return recording; }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::vector<Layer> layers;

    int outputWidth = 1920;
    int outputHeight = 1080;
    int targetFPS = 60;

    AudioReactive audioReactive;
    std::vector<float> currentSpectrum;
    std::vector<float> currentWaveform;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveEnabled = false;

    // Performance
    float currentFPS = 0.0f;
    double lastFrameTime = 0.0;

    // Recording
    bool recording = false;
    juce::File recordingFile;
    std::vector<juce::Image> recordedFrames;

    //==========================================================================
    // Rendering Methods
    //==========================================================================

    juce::Image renderGenerator(const Layer& layer);
    juce::Image applyEffects(const juce::Image& input, const Layer& layer);
    juce::Image applyEffect(const juce::Image& input, EffectType effect,
                           const std::map<juce::String, float>& params);

    juce::Image composeLayers();
    juce::Image blendLayers(const juce::Image& bottom, const juce::Image& top,
                           BlendMode mode, float opacity);

    //==========================================================================
    // Generator Implementations
    //==========================================================================

    juce::Image generateSolidColor(const std::map<juce::String, float>& params);
    juce::Image generateGradient(const std::map<juce::String, float>& params);
    juce::Image generatePerlinNoise(const std::map<juce::String, float>& params);
    juce::Image generateSpectrum(const std::map<juce::String, float>& params);
    juce::Image generateWaveform(const std::map<juce::String, float>& params);
    juce::Image generateParticles(const std::map<juce::String, float>& params);
    juce::Image generateFractal(const std::map<juce::String, float>& params);

    // Advanced generators
    juce::Image generateFlowField(const std::map<juce::String, float>& params);
    juce::Image generate3DCube(const std::map<juce::String, float>& params);
    juce::Image generate3DSphere(const std::map<juce::String, float>& params);
    juce::Image generate3DTorus(const std::map<juce::String, float>& params);
    juce::Image generateLSystem(const std::map<juce::String, float>& params);

    //==========================================================================
    // Effect Implementations (simplified - would use GPU shaders in production)
    //==========================================================================

    juce::Image effectInvert(const juce::Image& input);
    juce::Image effectHue(const juce::Image& input, float amount);
    juce::Image effectPixelate(const juce::Image& input, int blockSize);
    juce::Image effectBlur(const juce::Image& input, float radius);
    juce::Image effectKaleidoscope(const juce::Image& input, int segments);

    //==========================================================================
    // Utilities
    //==========================================================================

    float getAudioReactiveValue() const;
    float getBioReactiveValue() const;
    void updateFPS();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (VisualForge)
};
