#pragma once

/**
 * VisualizerBridge.h
 * Desktop Visualizer Integration for Echoelmusic Plugin
 *
 * Provides real-time audio visualization for the desktop plugin
 * Supports multiple visualization modes with bio-reactive features
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include <cstdint>
#include <vector>
#include <memory>
#include <functional>
#include <string>
#include <array>

namespace Echoelmusic {

// Forward declarations
class FFTProcessor;
class BioDataProvider;

/**
 * Color representation (RGBA)
 */
struct Color {
    float r = 0.0f;
    float g = 0.0f;
    float b = 0.0f;
    float a = 1.0f;

    Color() = default;
    Color(float r, float g, float b, float a = 1.0f) : r(r), g(g), b(b), a(a) {}

    static Color fromHSV(float h, float s, float v, float a = 1.0f);
    static Color fromCoherence(double coherence);

    uint32_t toARGB() const;
    uint32_t toRGBA() const;
};

/**
 * Visualization modes available
 */
enum class VisualizationMode {
    Spectrum,       // FFT spectrum analyzer
    Waveform,       // Oscilloscope
    Particles,      // Particle field
    Cymatics,       // Water-like patterns
    Mandala,        // Radial symmetric patterns
    Vaporwave,      // Retro neon grid
    Nebula,         // Cloud/nebula effect
    Kaleidoscope,   // Kaleidoscopic patterns
    FlowField,      // Vector flow visualization
    OctaveMap,      // Frequency octave mapping
    BioReactive,    // Heart/HRV visualization
    Custom          // User-defined
};

/**
 * Visualization parameters
 */
struct VisualizationParams {
    // Audio data
    std::array<float, 128> spectrumBands{};     // FFT spectrum (128 bands)
    std::array<float, 256> waveformSamples{};   // Waveform buffer
    float rmsLevel = 0.0f;                       // RMS level (0-1)
    float peakLevel = 0.0f;                      // Peak level (0-1)
    float dominantFrequency = 440.0f;           // Dominant frequency (Hz)

    // Frequency band levels (normalized 0-1)
    float subBass = 0.0f;    // 20-60 Hz
    float bass = 0.0f;       // 60-250 Hz
    float lowMid = 0.0f;     // 250-500 Hz
    float mid = 0.0f;        // 500-2000 Hz
    float highMid = 0.0f;    // 2000-4000 Hz
    float presence = 0.0f;   // 4000-6000 Hz
    float brilliance = 0.0f; // 6000-20000 Hz

    // Bio-reactive data
    double hrvCoherence = 50.0;   // 0-100
    double heartRate = 70.0;      // BPM
    double hrv = 50.0;            // HRV value
    double breathPhase = 0.0;     // 0-1 (breathing cycle)

    // Beat detection
    bool beatDetected = false;
    float beatIntensity = 0.0f;
    double bpm = 120.0;

    // Time
    double timeSeconds = 0.0;
    double deltaTime = 0.016;  // Frame delta
};

/**
 * Render target for visualization output
 */
struct RenderTarget {
    uint32_t* pixels = nullptr;    // ARGB pixel buffer
    int width = 0;
    int height = 0;
    int stride = 0;                // Bytes per row

    bool isValid() const { return pixels != nullptr && width > 0 && height > 0; }
    void clear(Color color = Color(0, 0, 0, 1));
    void setPixel(int x, int y, Color color);
    void drawLine(int x0, int y0, int x1, int y1, Color color);
    void fillRect(int x, int y, int w, int h, Color color);
    void drawCircle(int cx, int cy, int radius, Color color);
    void fillCircle(int cx, int cy, int radius, Color color);
};

/**
 * VisualizerBridge - Main visualization class for desktop plugin
 */
class VisualizerBridge {
public:
    VisualizerBridge();
    ~VisualizerBridge();

    // Initialization
    void initialize(int width, int height);
    void resize(int width, int height);
    void shutdown();

    // Mode control
    void setMode(VisualizationMode mode);
    VisualizationMode getMode() const { return currentMode_; }
    std::string getModeName() const;

    // Configuration
    void setColorScheme(const std::vector<Color>& colors);
    void setBioReactiveEnabled(bool enabled) { bioReactiveEnabled_ = enabled; }
    void setSensitivity(float sensitivity) { sensitivity_ = sensitivity; }
    void setSmoothing(float smoothing) { smoothing_ = smoothing; }

    // Update and render
    void updateAudioData(const float* spectrum, size_t spectrumSize,
                         const float* waveform, size_t waveformSize,
                         float rms, float peak);
    void updateBioData(double coherence, double heartRate, double hrv);
    void render(RenderTarget& target, double deltaTime);

    // FFT integration
    void processAudioBuffer(const float* samples, size_t sampleCount, int sampleRate);

    // Callbacks
    using BeatCallback = std::function<void(float intensity)>;
    void setBeatCallback(BeatCallback callback) { beatCallback_ = callback; }

private:
    // Mode-specific rendering
    void renderSpectrum(RenderTarget& target);
    void renderWaveform(RenderTarget& target);
    void renderParticles(RenderTarget& target);
    void renderCymatics(RenderTarget& target);
    void renderMandala(RenderTarget& target);
    void renderVaporwave(RenderTarget& target);
    void renderNebula(RenderTarget& target);
    void renderKaleidoscope(RenderTarget& target);
    void renderFlowField(RenderTarget& target);
    void renderOctaveMap(RenderTarget& target);
    void renderBioReactive(RenderTarget& target);

    // Helpers
    void detectBeat();
    void updateSmoothedValues();
    Color getColorForFrequency(float normalizedFreq);
    Color getBioReactiveColor();

    // State
    VisualizationMode currentMode_ = VisualizationMode::Spectrum;
    VisualizationParams params_;
    bool initialized_ = false;
    bool bioReactiveEnabled_ = true;

    // Configuration
    float sensitivity_ = 1.0f;
    float smoothing_ = 0.8f;
    std::vector<Color> colorScheme_;

    // Smoothed values
    std::array<float, 128> smoothedSpectrum_{};
    float smoothedRMS_ = 0.0f;

    // Beat detection
    float beatThreshold_ = 0.5f;
    float lastBeatTime_ = 0.0f;
    BeatCallback beatCallback_;

    // Particle system (for particle mode)
    struct Particle {
        float x, y;
        float vx, vy;
        float life;
        Color color;
    };
    std::vector<Particle> particles_;
    static constexpr size_t MAX_PARTICLES = 1000;

    // Time tracking
    double totalTime_ = 0.0;
};

/**
 * VisualizerFactory - Create visualizers with presets
 */
class VisualizerFactory {
public:
    static std::unique_ptr<VisualizerBridge> create(VisualizationMode mode);
    static std::vector<std::string> getAvailableModes();
    static VisualizationMode modeFromString(const std::string& name);
};

} // namespace Echoelmusic
