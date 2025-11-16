#pragma once

#include <JuceHeader.h>
#include "../Instrument/IntelligentSampler.h"

namespace Echoelmusic {

//==============================================================================
/**
 * @brief Zone Editor Component
 *
 * Visual editor for 128 sample zones with velocity and note ranges
 * Interactive grid showing all layers at once
 */
class ZoneEditor : public juce::Component,
                   public juce::Timer
{
public:
    ZoneEditor(IntelligentSampler& sampler);
    ~ZoneEditor() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void mouseDown(const juce::MouseEvent& event) override;
    void mouseDrag(const juce::MouseEvent& event) override;
    void mouseUp(const juce::MouseEvent& event) override;

    void setSelectedLayer(int layerIndex);
    int getSelectedLayer() const { return selectedLayer; }

private:
    IntelligentSampler& sampler;

    struct ZoneVisual {
        int layerID;
        int lowNote, highNote;
        int lowVelocity, highVelocity;
        juce::String articulation;
        juce::Colour color;
        bool enabled;
        int roundRobinGroup;
    };

    std::vector<ZoneVisual> zones;
    int selectedLayer = -1;
    int hoveredLayer = -1;

    // Interaction state
    bool isDragging = false;
    juce::Point<int> dragStart;

    void updateZoneData();
    void drawPianoKeyboard(juce::Graphics& g, juce::Rectangle<float> bounds);
    void drawVelocityAxis(juce::Graphics& g, juce::Rectangle<float> bounds);
    void drawZone(juce::Graphics& g, const ZoneVisual& zone, juce::Rectangle<float> gridBounds);
    juce::Colour getArticulationColor(const juce::String& articulation);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ZoneEditor)
};

//==============================================================================
/**
 * @brief Sample Waveform Display
 *
 * Shows waveform with loop points, pitch detection, and articulation info
 */
class SampleWaveformDisplay : public juce::Component,
                               public juce::Timer
{
public:
    SampleWaveformDisplay();
    ~SampleWaveformDisplay() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    void loadSample(const juce::AudioBuffer<float>& buffer, int sampleRate);
    void setLoopPoints(int start, int end, float quality);
    void setPitchInfo(int midiNote, float confidence);
    void setArticulation(const juce::String& type);

    void mouseDown(const juce::MouseEvent& event) override;
    void mouseDrag(const juce::MouseEvent& event) override;

private:
    juce::AudioBuffer<float> sampleBuffer;
    int sampleRate = 44100;

    // Loop points
    int loopStart = 0;
    int loopEnd = 0;
    float loopQuality = 0.0f;
    bool draggingLoopStart = false;
    bool draggingLoopEnd = false;

    // Pitch info
    int detectedMidiNote = 60;
    float pitchConfidence = 0.0f;

    // Articulation
    juce::String articulationType = "Unknown";

    // Zoom/pan
    float zoomLevel = 1.0f;
    float panPosition = 0.0f;

    void drawWaveform(juce::Graphics& g, juce::Rectangle<float> bounds);
    void drawLoopMarkers(juce::Graphics& g, juce::Rectangle<float> bounds);
    void drawInfoOverlay(juce::Graphics& g, juce::Rectangle<float> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SampleWaveformDisplay)
};

//==============================================================================
/**
 * @brief Layer Manager Component
 *
 * List view of all 128 layers with controls
 */
class LayerManager : public juce::Component,
                     public juce::ListBoxModel,
                     public juce::Button::Listener
{
public:
    LayerManager(IntelligentSampler& sampler);
    ~LayerManager() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    // ListBoxModel implementation
    int getNumRows() override;
    void paintListBoxItem(int rowNumber, juce::Graphics& g,
                         int width, int height, bool rowIsSelected) override;
    void listBoxItemClicked(int row, const juce::MouseEvent&) override;
    Component* refreshComponentForRow(int rowNumber, bool isRowSelected,
                                     Component* existingComponentToUpdate) override;

    // Button listener
    void buttonClicked(juce::Button* button) override;

    void setSelectedLayer(int layerIndex);

private:
    IntelligentSampler& sampler;

    struct LayerInfo {
        int id;
        bool enabled;
        bool solo;
        bool mute;
        int rootNote;
        juce::String noteName;
        int lowVelocity, highVelocity;
        juce::String articulation;
        juce::String engine; // Classic, Stretch, Granular, Spectral, Hybrid
        int roundRobinGroup;
    };

    std::vector<LayerInfo> layers;
    juce::ListBox layerList;
    int selectedLayer = -1;

    // Sort controls
    juce::ComboBox sortByCombo;
    juce::TextButton enableAllButton;
    juce::TextButton disableAllButton;

    void updateLayerData();
    void sortLayers(const juce::String& sortBy);

    // Custom component for layer row
    class LayerRowComponent : public juce::Component
    {
    public:
        LayerRowComponent(LayerManager& owner, int layerID);
        void paint(juce::Graphics& g) override;
        void resized() override;

    private:
        LayerManager& owner;
        int layerID;
        juce::ToggleButton enableToggle;
        juce::TextButton soloButton;
        juce::TextButton muteButton;
        juce::ComboBox engineCombo;
    };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LayerManager)
};

//==============================================================================
/**
 * @brief Main IntelligentSampler UI Component
 *
 * Complete UI for IntelligentSampler with all visualizations and controls
 */
class IntelligentSamplerUI : public juce::Component,
                             public juce::Slider::Listener,
                             public juce::Button::Listener,
                             public juce::ComboBox::Listener
{
public:
    IntelligentSamplerUI(IntelligentSampler& sampler);
    ~IntelligentSamplerUI() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    // Slider listener
    void sliderValueChanged(juce::Slider* slider) override;

    // Button listener
    void buttonClicked(juce::Button* button) override;

    // ComboBox listener
    void comboBoxChanged(juce::ComboBox* comboBox) override;

private:
    IntelligentSampler& sampler;

    // Main components
    std::unique_ptr<ZoneEditor> zoneEditor;
    std::unique_ptr<SampleWaveformDisplay> waveformDisplay;
    std::unique_ptr<LayerManager> layerManager;
    std::unique_ptr<BioDataVisualizer> bioDataViz;

    // AI Controls
    juce::TextButton autoMapButton;
    juce::ToggleButton pitchDetectionToggle;
    juce::ToggleButton loopFinderToggle;
    juce::ToggleButton articulationDetectionToggle;

    // Sample Engine
    juce::ComboBox sampleEngineCombo;
    juce::Label sampleEngineLabel;

    // Filter controls
    juce::Slider filterCutoffSlider;
    juce::Slider filterResonanceSlider;
    juce::ComboBox filterTypeCombo;

    // Envelope controls
    juce::Slider attackSlider;
    juce::Slider decaySlider;
    juce::Slider sustainSlider;
    juce::Slider releaseSlider;

    // Bio-reactive controls
    juce::ToggleButton bioReactiveToggle;
    juce::Slider hrvMappingSlider;
    juce::Slider coherenceMappingSlider;
    juce::Slider breathMappingSlider;

    // File operations
    juce::TextButton loadFolderButton;
    juce::TextButton loadSampleButton;
    juce::TextButton saveMappingButton;

    // Labels
    juce::Label titleLabel;
    std::vector<std::unique_ptr<juce::Label>> paramLabels;

    // Layer count display
    juce::Label layerCountLabel;

    void createControls();
    void createLabels();
    void layoutComponents();
    void updateLayerCount();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(IntelligentSamplerUI)
};

} // namespace Echoelmusic
