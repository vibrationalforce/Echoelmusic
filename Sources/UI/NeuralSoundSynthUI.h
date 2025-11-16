#pragma once

#include <JuceHeader.h>
#include "../Synth/NeuralSoundSynth.h"

namespace Echoelmusic {

//==============================================================================
/**
 * @brief Latent Space 2D Visualizer
 *
 * Visualizes the 128-dimensional latent space projected to 2D using PCA
 * Shows current position, allows dragging to navigate the latent space
 */
class LatentSpaceVisualizer : public juce::Component,
                               public juce::Timer
{
public:
    LatentSpaceVisualizer(NeuralSoundSynth& synth);
    ~LatentSpaceVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void mouseDown(const juce::MouseEvent& event) override;
    void mouseDrag(const juce::MouseEvent& event) override;
    void mouseUp(const juce::MouseEvent& event) override;

private:
    NeuralSoundSynth& synthesizer;

    // Current latent position (2D projection)
    juce::Point<float> currentPosition{0.5f, 0.5f};
    juce::Point<float> targetPosition{0.5f, 0.5f};

    // Latent space grid (for visualization)
    std::vector<juce::Point<float>> gridPoints;
    std::vector<juce::Colour> gridColors;

    // History trail
    std::deque<juce::Point<float>> positionHistory;
    static constexpr int maxHistorySize = 100;

    void updateLatentPosition(juce::Point<float> position);
    void generateLatentGrid();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LatentSpaceVisualizer)
};

//==============================================================================
/**
 * @brief Bio-Data Visualizer
 *
 * Real-time visualization of HRV, Coherence, and Breath data
 * Shows waveforms, current values, and historical trends
 */
class BioDataVisualizer : public juce::Component,
                          public juce::Timer
{
public:
    BioDataVisualizer();
    ~BioDataVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void updateBioData(float hrv, float coherence, float breath);

private:
    // Bio-data history (60 seconds @ 60Hz = 3600 samples)
    std::deque<float> hrvHistory;
    std::deque<float> coherenceHistory;
    std::deque<float> breathHistory;
    static constexpr int maxHistorySize = 3600;

    // Current values
    float currentHRV = 50.0f;
    float currentCoherence = 0.5f;
    float currentBreath = 0.5f;

    // Display rectangles
    juce::Rectangle<float> hrvRect;
    juce::Rectangle<float> coherenceRect;
    juce::Rectangle<float> breathRect;

    void drawWaveform(juce::Graphics& g,
                     const std::deque<float>& data,
                     juce::Rectangle<float> bounds,
                     juce::Colour color,
                     float minVal, float maxVal);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioDataVisualizer)
};

//==============================================================================
/**
 * @brief Waveform Visualizer
 *
 * Real-time waveform display with spectral overlay
 */
class WaveformVisualizer : public juce::Component,
                           public juce::Timer
{
public:
    WaveformVisualizer();
    ~WaveformVisualizer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void pushAudioSample(float sample);
    void pushAudioBuffer(const juce::AudioBuffer<float>& buffer);

private:
    // Waveform buffer (circular buffer)
    std::vector<float> waveformBuffer;
    int bufferWritePosition = 0;
    static constexpr int bufferSize = 2048;

    // FFT for spectral overlay
    juce::dsp::FFT fft{11}; // 2^11 = 2048
    std::array<float, 4096> fftData;

    void drawWaveform(juce::Graphics& g, juce::Rectangle<float> bounds);
    void drawSpectrum(juce::Graphics& g, juce::Rectangle<float> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WaveformVisualizer)
};

//==============================================================================
/**
 * @brief Preset Browser Component
 *
 * Visual preset browser with categories and search
 */
class PresetBrowser : public juce::Component,
                      public juce::ListBoxModel
{
public:
    PresetBrowser();
    ~PresetBrowser() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    // ListBoxModel implementation
    int getNumRows() override;
    void paintListBoxItem(int rowNumber, juce::Graphics& g,
                         int width, int height, bool rowIsSelected) override;
    void listBoxItemClicked(int row, const juce::MouseEvent&) override;

    void loadPresets(const juce::File& presetDirectory);
    juce::String getSelectedPreset() const;

private:
    juce::ListBox presetList;
    juce::TextEditor searchBox;
    juce::ComboBox categoryFilter;

    struct PresetInfo {
        juce::String name;
        juce::String category;
        juce::String description;
        juce::File file;
    };

    std::vector<PresetInfo> allPresets;
    std::vector<PresetInfo> filteredPresets;
    int selectedRow = -1;

    void filterPresets();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetBrowser)
};

//==============================================================================
/**
 * @brief Main NeuralSoundSynth UI Component
 *
 * Complete UI for NeuralSoundSynth with all visualizations and controls
 */
class NeuralSoundSynthUI : public juce::Component,
                           public juce::Slider::Listener,
                           public juce::Button::Listener
{
public:
    NeuralSoundSynthUI(NeuralSoundSynth& synth);
    ~NeuralSoundSynthUI() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    // Slider listener
    void sliderValueChanged(juce::Slider* slider) override;

    // Button listener
    void buttonClicked(juce::Button* button) override;

private:
    NeuralSoundSynth& synthesizer;

    // Visualizers
    std::unique_ptr<LatentSpaceVisualizer> latentSpaceViz;
    std::unique_ptr<BioDataVisualizer> bioDataViz;
    std::unique_ptr<WaveformVisualizer> waveformViz;
    std::unique_ptr<PresetBrowser> presetBrowser;

    // Parameter controls
    juce::Slider latentDim1Slider;
    juce::Slider latentDim2Slider;
    juce::Slider temperatureSlider;
    juce::Slider morphSpeedSlider;

    juce::ComboBox synthModeCombo;

    juce::ToggleButton bioReactiveToggle;

    juce::TextButton loadPresetButton;
    juce::TextButton savePresetButton;
    juce::TextButton randomizeButton;

    // Labels
    juce::Label titleLabel;
    std::vector<std::unique_ptr<juce::Label>> paramLabels;

    // Layout helper
    void createParameterControls();
    void createLabels();
    void layoutComponents();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(NeuralSoundSynthUI)
};

} // namespace Echoelmusic
