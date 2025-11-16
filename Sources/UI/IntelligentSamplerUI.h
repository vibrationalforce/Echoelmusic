#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <array>

/**
 * IntelligentSamplerUI - Advanced Sample Management and Zone Editor
 *
 * Features:
 * - Multi-layer sample management with drag-and-drop support
 * - Interactive zone editor with visual keyzone mapping
 * - Real-time waveform display with zoom and scroll
 * - ML-powered sample analysis and automatic zone creation
 * - Velocity layer management
 * - Round-robin and random sample triggering
 * - Time-stretching and pitch-shifting controls
 * - Multi-sample export functionality
 */
class IntelligentSamplerUI : public juce::Component,
                             public juce::DragAndDropContainer,
                             public juce::FileDragAndDropTarget,
                             public juce::Timer
{
public:
    explicit IntelligentSamplerUI(juce::AudioProcessorValueTreeState& vts);
    ~IntelligentSamplerUI() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    // Drag and drop
    bool isInterestedInFileDrag(const juce::StringArray& files) override;
    void filesDropped(const juce::StringArray& files, int x, int y) override;

    // Sample management
    void loadSample(const juce::File& file);
    void clearAllSamples();

private:
    // Forward declarations of nested classes
    class ZoneEditor;
    class WaveformDisplay;
    class LayerManager;
    class MLAnalyzer;
    class VelocityLayerEditor;

    // UI Components
    std::unique_ptr<ZoneEditor> zoneEditor;
    std::unique_ptr<WaveformDisplay> waveformDisplay;
    std::unique_ptr<LayerManager> layerManager;
    std::unique_ptr<MLAnalyzer> mlAnalyzer;
    std::unique_ptr<VelocityLayerEditor> velocityLayerEditor;

    // Controls
    juce::TextButton loadSampleButton;
    juce::TextButton clearButton;
    juce::TextButton autoMapButton;
    juce::TextButton exportButton;

    juce::Slider attackSlider;
    juce::Slider decaySlider;
    juce::Slider sustainSlider;
    juce::Slider releaseSlider;
    juce::Slider pitchSlider;
    juce::Slider volumeSlider;

    juce::Label attackLabel;
    juce::Label decayLabel;
    juce::Label sustainLabel;
    juce::Label releaseLabel;
    juce::Label pitchLabel;
    juce::Label volumeLabel;

    juce::ComboBox triggerModeCombo;
    juce::Label triggerModeLabel;

    // Parameter state
    juce::AudioProcessorValueTreeState& parameters;

    // Sample data
    struct SampleData
    {
        juce::AudioBuffer<float> buffer;
        double sampleRate = 44100.0;
        juce::String name;
        int rootNote = 60;
        int lowNote = 0;
        int highNote = 127;
        int lowVelocity = 0;
        int highVelocity = 127;
        juce::Colour color;
    };

    std::vector<SampleData> loadedSamples;

    // Helper methods
    void setupControls();
    void setupSlider(juce::Slider& slider, juce::Label& label,
                     double min, double max, double defaultValue);
    void analyzeAndCreateZones();
    void applyCustomLookAndFeel();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(IntelligentSamplerUI)
};

/**
 * Zone Editor - Visual keyzone and velocity mapping
 */
class IntelligentSamplerUI::ZoneEditor : public juce::Component
{
public:
    ZoneEditor();
    ~ZoneEditor() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent& e) override;
    void mouseDrag(const juce::MouseEvent& e) override;

    struct Zone
    {
        int lowKey;
        int highKey;
        int lowVelocity;
        int highVelocity;
        juce::Colour color;
        juce::String sampleName;
    };

    void addZone(const Zone& zone);
    void clearZones();
    const std::vector<Zone>& getZones() const { return zones; }

private:
    std::vector<Zone> zones;
    int selectedZoneIndex = -1;

    void drawKeyboard(juce::Graphics& g);
    void drawZones(juce::Graphics& g);
    int keyFromX(int x) const;
    int velocityFromY(int y) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ZoneEditor)
};

/**
 * Waveform Display - Real-time waveform visualization with zoom
 */
class IntelligentSamplerUI::WaveformDisplay : public juce::Component
{
public:
    WaveformDisplay();
    ~WaveformDisplay() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseWheelMove(const juce::MouseEvent& e, const juce::MouseWheelDetails& wheel) override;

    void setAudioBuffer(const juce::AudioBuffer<float>& buffer, double sampleRate);
    void setPlaybackPosition(double position);

private:
    juce::AudioBuffer<float> audioBuffer;
    double sampleRate = 44100.0;
    double zoomLevel = 1.0;
    double scrollPosition = 0.0;
    double playbackPosition = 0.0;

    juce::Path waveformPath;
    void generateWaveformPath();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WaveformDisplay)
};

/**
 * Layer Manager - Multi-layer sample management
 */
class IntelligentSamplerUI::LayerManager : public juce::Component,
                                           public juce::TableListBoxModel
{
public:
    LayerManager();
    ~LayerManager() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    // TableListBoxModel overrides
    int getNumRows() override;
    void paintRowBackground(juce::Graphics& g, int rowNumber, int width, int height, bool rowIsSelected) override;
    void paintCell(juce::Graphics& g, int rowNumber, int columnId, int width, int height, bool rowIsSelected) override;

    struct Layer
    {
        juce::String name;
        bool enabled = true;
        float volume = 1.0f;
        int pan = 0;
        juce::Colour color;
    };

    void addLayer(const Layer& layer);
    void removeLayer(int index);
    void clearLayers();
    const std::vector<Layer>& getLayers() const { return layers; }

private:
    std::vector<Layer> layers;
    juce::TableListBox table;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LayerManager)
};

/**
 * ML Analyzer - Machine learning powered sample analysis
 */
class IntelligentSamplerUI::MLAnalyzer : public juce::Component
{
public:
    MLAnalyzer();
    ~MLAnalyzer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;

    struct AnalysisResult
    {
        float fundamentalFrequency = 0.0f;
        int estimatedRootNote = 60;
        float noisiness = 0.0f;
        float brightness = 0.0f;
        float attack = 0.0f;
        float decay = 0.0f;
        std::vector<float> spectralCentroid;
    };

    AnalysisResult analyzeSample(const juce::AudioBuffer<float>& buffer, double sampleRate);
    void displayAnalysis(const AnalysisResult& result);

private:
    AnalysisResult currentAnalysis;
    juce::String analysisText;

    float detectPitch(const juce::AudioBuffer<float>& buffer, double sampleRate);
    float calculateSpectralCentroid(const std::vector<float>& spectrum);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MLAnalyzer)
};

/**
 * Velocity Layer Editor - Velocity-based layer mapping
 */
class IntelligentSamplerUI::VelocityLayerEditor : public juce::Component
{
public:
    VelocityLayerEditor();
    ~VelocityLayerEditor() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent& e) override;
    void mouseDrag(const juce::MouseEvent& e) override;

    struct VelocityLayer
    {
        int lowVelocity;
        int highVelocity;
        float volume;
        juce::Colour color;
    };

    void addVelocityLayer(const VelocityLayer& layer);
    void clearLayers();
    const std::vector<VelocityLayer>& getLayers() const { return layers; }

private:
    std::vector<VelocityLayer> layers;
    int selectedLayerIndex = -1;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VelocityLayerEditor)
};
