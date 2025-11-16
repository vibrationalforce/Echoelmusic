#pragma once

#include <JuceHeader.h>
#include "../Synth/SpectralGranularSynth.h"

namespace Echoelmusic {

//==============================================================================
/**
 * @brief Grain Cloud Visualizer
 *
 * Real-time visualization of all 32 grain streams with 8,192 total grains
 * Shows position, pitch, size, and envelope for each active grain
 */
class GrainCloudVisualizer : public juce::Component,
                             public juce::Timer
{
public:
    GrainCloudVisualizer(SpectralGranularSynth& synth);
    ~GrainCloudVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

private:
    SpectralGranularSynth& synthesizer;

    struct GrainVisual {
        juce::Point<float> position;
        float size;
        float pitch;
        float alpha;
        juce::Colour color;
        int streamID;
    };

    std::vector<GrainVisual> activeGrains;
    static constexpr int maxVisualizationGrains = 256; // Visualize subset

    void updateGrainData();
    void drawGrain(juce::Graphics& g, const GrainVisual& grain, juce::Rectangle<float> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GrainCloudVisualizer)
};

//==============================================================================
/**
 * @brief Spectral Analyzer
 *
 * Real-time FFT display with spectral mask visualization
 */
class SpectralAnalyzer : public juce::Component,
                         public juce::Timer
{
public:
    SpectralAnalyzer();
    ~SpectralAnalyzer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void pushAudioBuffer(const juce::AudioBuffer<float>& buffer);
    void setSpectralMask(float lowFreq, float highFreq);

private:
    juce::dsp::FFT fft{12}; // 2^12 = 4096
    std::array<float, 8192> fftData;
    std::array<float, 4096> spectrumData;

    float maskLowFreq = 100.0f;
    float maskHighFreq = 15000.0f;

    juce::AudioBuffer<float> audioFifo;
    int fifoIndex = 0;
    bool nextFFTBlockReady = false;

    void drawSpectrum(juce::Graphics& g, juce::Rectangle<float> bounds);
    void drawSpectralMask(juce::Graphics& g, juce::Rectangle<float> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralAnalyzer)
};

//==============================================================================
/**
 * @brief Swarm Behavior Visualizer
 *
 * Visualizes particle-based grain behavior with chaos/attraction/repulsion
 */
class SwarmVisualizer : public juce::Component,
                        public juce::Timer
{
public:
    SwarmVisualizer();
    ~SwarmVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void setSwarmParameters(float chaos, float attraction, float repulsion);

private:
    struct Particle {
        juce::Point<float> position;
        juce::Point<float> velocity;
        juce::Colour color;
    };

    std::vector<Particle> particles;
    static constexpr int numParticles = 100;

    float chaosAmount = 0.5f;
    float attractionAmount = 0.5f;
    float repulsionAmount = 0.5f;

    juce::Point<float> attractorPosition{0.5f, 0.5f};

    void updateParticles();
    void drawParticle(juce::Graphics& g, const Particle& particle, juce::Rectangle<float> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SwarmVisualizer)
};

//==============================================================================
/**
 * @brief Texture Mode Visualizer
 *
 * Visualizes emergent texture complexity and evolution
 */
class TextureVisualizer : public juce::Component,
                          public juce::Timer
{
public:
    TextureVisualizer();
    ~TextureVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void setTextureParameters(float complexity, float evolution, float randomness);

private:
    float complexityAmount = 0.5f;
    float evolutionAmount = 0.5f;
    float randomnessAmount = 0.5f;

    juce::Image textureImage;
    void generateTexture();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TextureVisualizer)
};

//==============================================================================
/**
 * @brief Main SpectralGranularSynth UI Component
 *
 * Complete UI for SpectralGranularSynth with all visualizations and controls
 */
class SpectralGranularSynthUI : public juce::Component,
                                public juce::Slider::Listener,
                                public juce::Button::Listener,
                                public juce::ComboBox::Listener
{
public:
    SpectralGranularSynthUI(SpectralGranularSynth& synth);
    ~SpectralGranularSynthUI() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    // Slider listener
    void sliderValueChanged(juce::Slider* slider) override;

    // Button listener
    void buttonClicked(juce::Button* button) override;

    // ComboBox listener
    void comboBoxChanged(juce::ComboBox* comboBox) override;

private:
    SpectralGranularSynth& synthesizer;

    // Visualizers
    std::unique_ptr<GrainCloudVisualizer> grainCloudViz;
    std::unique_ptr<SpectralAnalyzer> spectralAnalyzer;
    std::unique_ptr<SwarmVisualizer> swarmViz;
    std::unique_ptr<TextureVisualizer> textureViz;
    std::unique_ptr<BioDataVisualizer> bioDataViz;

    // Global parameters
    juce::Slider grainSizeSlider;
    juce::Slider densitySlider;
    juce::Slider positionSlider;
    juce::Slider pitchSlider;

    // Spray parameters
    juce::Slider positionSpraySlider;
    juce::Slider pitchSpraySlider;
    juce::Slider panSpraySlider;
    juce::Slider sizeSpraySlider;

    // Spectral parameters
    juce::Slider maskLowSlider;
    juce::Slider maskHighSlider;
    juce::Slider tonalitySlider;
    juce::Slider noisinessSlider;

    // Swarm parameters
    juce::Slider chaosSlider;
    juce::Slider attractionSlider;
    juce::Slider repulsionSlider;

    // Texture parameters
    juce::Slider complexitySlider;
    juce::Slider evolutionSlider;
    juce::Slider randomnessSlider;

    // Mode selection
    juce::ComboBox grainModeCombo;
    juce::ComboBox envelopeShapeCombo;
    juce::ComboBox directionCombo;

    // Toggles
    juce::ToggleButton freezeModeToggle;
    juce::ToggleButton swarmModeToggle;
    juce::ToggleButton textureModeToggle;
    juce::ToggleButton bioReactiveToggle;

    // Stream count selector
    juce::Slider streamCountSlider;

    // Labels
    juce::Label titleLabel;
    std::vector<std::unique_ptr<juce::Label>> paramLabels;

    // Tabbed view for different parameter sections
    juce::TabbedComponent parameterTabs;

    void createParameterControls();
    void createLabels();
    void layoutComponents();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectralGranularSynthUI)
};

} // namespace Echoelmusic
