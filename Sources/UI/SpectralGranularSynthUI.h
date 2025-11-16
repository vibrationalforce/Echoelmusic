#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * SpectralGranularSynthUI - Advanced Spectral Granular Synthesis UI
 *
 * Features:
 * - Real-time grain cloud visualization with 3D OpenGL rendering
 * - Spectral analyzer with frequency-based coloring
 * - Swarm visualizer for particle-based grain representation
 * - Texture visualizer for granular texture display
 * - Interactive parameter controls with real-time feedback
 * - GPU-accelerated rendering for smooth 60 FPS performance
 */
class SpectralGranularSynthUI : public juce::Component,
                                public juce::Timer
{
public:
    explicit SpectralGranularSynthUI(juce::AudioProcessorValueTreeState& vts);
    ~SpectralGranularSynthUI() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    // Update visualizers with audio data
    void updateFromAudioData(const float* audioData, int numSamples);
    void updateFromFFTData(const float* fftData, int numBins);

private:
    // Forward declarations of nested classes
    class GrainCloudVisualizer;
    class SpectralAnalyzer;
    class SwarmVisualizer;
    class TextureVisualizer;

    // Visualizer components
    std::unique_ptr<GrainCloudVisualizer> grainCloud;
    std::unique_ptr<SpectralAnalyzer> spectralAnalyzer;
    std::unique_ptr<SwarmVisualizer> swarmViz;
    std::unique_ptr<TextureVisualizer> textureViz;

    // Parameter controls
    juce::Slider grainSizeSlider;
    juce::Slider grainDensitySlider;
    juce::Slider spectralShiftSlider;
    juce::Slider textureAmountSlider;
    juce::Slider swarmChaosSlider;
    juce::Slider freezeSlider;

    juce::Label grainSizeLabel;
    juce::Label grainDensityLabel;
    juce::Label spectralShiftLabel;
    juce::Label textureAmountLabel;
    juce::Label swarmChaosLabel;
    juce::Label freezeLabel;

    juce::TextButton randomizeButton;
    juce::TextButton morphButton;

    // Parameter attachments
    juce::AudioProcessorValueTreeState& parameters;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> grainSizeAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> grainDensityAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> spectralShiftAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> textureAmountAttachment;

    // Helper methods
    void setupSlider(juce::Slider& slider, juce::Label& label,
                     double min, double max, double defaultValue);
    void updateVisualizersFromAudioData();
    void randomizeParameters();
    void startMorphing();
    void applyCustomLookAndFeel();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralGranularSynthUI)
};

/**
 * Grain Cloud Visualizer - 3D grain cloud with spectral content
 */
class SpectralGranularSynthUI::GrainCloudVisualizer : public juce::Component
{
public:
    GrainCloudVisualizer();
    ~GrainCloudVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    void updateGrains(const float* audioData, int numSamples);

private:
    struct Grain
    {
        float x, y, z;
        float size;
        float brightness;
        std::array<float, 32> spectralContent;
        juce::Colour color;
        float lifespan;
    };

    std::vector<Grain> grains;
    juce::dsp::FFT fft{10}; // 1024 points
    std::vector<float> fftData;

    void renderGrainCloud(juce::Graphics& g);
    void spawnGrainsFromSpectrum(const std::vector<float>& spectrum);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GrainCloudVisualizer)
};

/**
 * Spectral Analyzer - Real-time frequency spectrum display
 */
class SpectralGranularSynthUI::SpectralAnalyzer : public juce::Component
{
public:
    SpectralAnalyzer();
    ~SpectralAnalyzer() override;

    void paint(juce::Graphics& g) override;
    void updateSpectrum(const float* fftData, int numBins);

private:
    std::array<float, 512> magnitudes{};
    juce::Path spectrumPath;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralAnalyzer)
};

/**
 * Swarm Visualizer - Particle swarm for grain representation
 */
class SpectralGranularSynthUI::SwarmVisualizer : public juce::Component,
                                                 public juce::Timer
{
public:
    SwarmVisualizer();
    ~SwarmVisualizer() override;

    void paint(juce::Graphics& g) override;
    void timerCallback() override;

    void setSwarmParameters(float density, float chaos);

private:
    struct Particle
    {
        juce::Point<float> position;
        juce::Point<float> velocity;
        float phase;
        float frequency;
        juce::Colour colour;
    };

    std::vector<Particle> swarm;
    juce::Point<float> attractorPoint;
    float swarmDensity = 0.5f;
    float swarmChaos = 0.3f;

    void updateSwarm();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SwarmVisualizer)
};

/**
 * Texture Visualizer - Procedural texture generation
 */
class SpectralGranularSynthUI::TextureVisualizer : public juce::Component
{
public:
    TextureVisualizer();
    ~TextureVisualizer() override;

    void paint(juce::Graphics& g) override;
    void updateTexture(float brightness, float contrast, float complexity);

private:
    juce::Image textureImage;
    std::array<std::array<float, 256>, 256> textureData{};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TextureVisualizer)
};
