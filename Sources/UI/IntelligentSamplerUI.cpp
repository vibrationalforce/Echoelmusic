#include "IntelligentSamplerUI.h"

//==============================================================================
// ZoneEditor Implementation
//==============================================================================

IntelligentSamplerUI::ZoneEditor::ZoneEditor()
{
    setOpaque(true);
}

IntelligentSamplerUI::ZoneEditor::~ZoneEditor() = default;

void IntelligentSamplerUI::ZoneEditor::paint(juce::Graphics& g)
{
    // Background
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xff1a1a2e), 0.0f, 0.0f,
        juce::Colour(0xff0f0f1e), 0.0f, static_cast<float>(getHeight()), false));
    g.fillAll();

    drawKeyboard(g);
    drawZones(g);

    // Grid lines
    g.setColour(juce::Colours::white.withAlpha(0.1f));
    for (int i = 1; i < 8; ++i)
    {
        float y = static_cast<float>(getHeight()) * static_cast<float>(i) / 8.0f;
        g.drawHorizontalLine(static_cast<int>(y), 0.0f, static_cast<float>(getWidth()));
    }
}

void IntelligentSamplerUI::ZoneEditor::resized()
{
    // Update layout if needed
}

void IntelligentSamplerUI::ZoneEditor::drawKeyboard(juce::Graphics& g)
{
    const int numKeys = 88; // Piano keyboard
    const float keyWidth = static_cast<float>(getWidth()) / static_cast<float>(numKeys);

    for (int i = 0; i < numKeys; ++i)
    {
        int noteInOctave = (i + 9) % 12; // Starting from A0
        bool isBlackKey = (noteInOctave == 1 || noteInOctave == 3 || noteInOctave == 6 ||
                          noteInOctave == 8 || noteInOctave == 10);

        float x = static_cast<float>(i) * keyWidth;

        if (isBlackKey)
        {
            g.setColour(juce::Colour(0xff333333));
        }
        else
        {
            g.setColour(juce::Colour(0xffeeeeee));
        }

        g.fillRect(x, static_cast<float>(getHeight()) - 20.0f, keyWidth - 1.0f, 20.0f);

        // Draw key outline
        g.setColour(juce::Colours::black.withAlpha(0.3f));
        g.drawRect(x, static_cast<float>(getHeight()) - 20.0f, keyWidth - 1.0f, 20.0f, 0.5f);

        // Mark C notes
        if (noteInOctave == 3) // C note
        {
            g.setColour(juce::Colours::red.withAlpha(0.5f));
            g.fillRect(x, static_cast<float>(getHeight()) - 5.0f, keyWidth - 1.0f, 5.0f);
        }
    }
}

void IntelligentSamplerUI::ZoneEditor::drawZones(juce::Graphics& g)
{
    for (size_t i = 0; i < zones.size(); ++i)
    {
        const auto& zone = zones[i];

        float x1 = (static_cast<float>(zone.lowKey) / 88.0f) * static_cast<float>(getWidth());
        float x2 = (static_cast<float>(zone.highKey) / 88.0f) * static_cast<float>(getWidth());
        float y1 = (1.0f - (static_cast<float>(zone.highVelocity) / 127.0f)) * (static_cast<float>(getHeight()) - 20.0f);
        float y2 = (1.0f - (static_cast<float>(zone.lowVelocity) / 127.0f)) * (static_cast<float>(getHeight()) - 20.0f);

        // Zone rectangle
        g.setColour(zone.color.withAlpha(0.3f));
        g.fillRect(x1, y1, x2 - x1, y2 - y1);

        // Zone outline
        g.setColour(zone.color);
        g.drawRect(x1, y1, x2 - x1, y2 - y1, 2.0f);

        // Selected zone highlight
        if (static_cast<int>(i) == selectedZoneIndex)
        {
            g.setColour(juce::Colours::white);
            g.drawRect(x1 - 2.0f, y1 - 2.0f, x2 - x1 + 4.0f, y2 - y1 + 4.0f, 3.0f);
        }

        // Zone label
        g.setColour(juce::Colours::white);
        g.setFont(10.0f);
        g.drawText(zone.sampleName, juce::Rectangle<float>(x1, y1, x2 - x1, 20.0f),
                  juce::Justification::centred, true);
    }
}

void IntelligentSamplerUI::ZoneEditor::mouseDown(const juce::MouseEvent& e)
{
    // Select zone on click
    int key = keyFromX(e.x);
    int velocity = velocityFromY(e.y);

    selectedZoneIndex = -1;
    for (size_t i = 0; i < zones.size(); ++i)
    {
        if (key >= zones[i].lowKey && key <= zones[i].highKey &&
            velocity >= zones[i].lowVelocity && velocity <= zones[i].highVelocity)
        {
            selectedZoneIndex = static_cast<int>(i);
            break;
        }
    }

    repaint();
}

void IntelligentSamplerUI::ZoneEditor::mouseDrag(const juce::MouseEvent& e)
{
    if (selectedZoneIndex >= 0 && selectedZoneIndex < static_cast<int>(zones.size()))
    {
        // Allow dragging to adjust zone boundaries
        repaint();
    }
}

void IntelligentSamplerUI::ZoneEditor::addZone(const Zone& zone)
{
    zones.push_back(zone);
    repaint();
}

void IntelligentSamplerUI::ZoneEditor::clearZones()
{
    zones.clear();
    selectedZoneIndex = -1;
    repaint();
}

int IntelligentSamplerUI::ZoneEditor::keyFromX(int x) const
{
    return static_cast<int>((static_cast<float>(x) / static_cast<float>(getWidth())) * 88.0f);
}

int IntelligentSamplerUI::ZoneEditor::velocityFromY(int y) const
{
    float normalizedY = static_cast<float>(y) / (static_cast<float>(getHeight()) - 20.0f);
    return static_cast<int>((1.0f - normalizedY) * 127.0f);
}

//==============================================================================
// WaveformDisplay Implementation
//==============================================================================

IntelligentSamplerUI::WaveformDisplay::WaveformDisplay()
{
    setOpaque(true);
}

IntelligentSamplerUI::WaveformDisplay::~WaveformDisplay() = default;

void IntelligentSamplerUI::WaveformDisplay::paint(juce::Graphics& g)
{
    // Background
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xff0a0a0f), 0.0f, 0.0f,
        juce::Colour(0xff1a1a2e), static_cast<float>(getWidth()), 0.0f, false));
    g.fillAll();

    // Draw waveform
    if (!waveformPath.isEmpty())
    {
        g.setColour(juce::Colours::cyan.withAlpha(0.3f));
        g.fillPath(waveformPath);

        g.setColour(juce::Colours::cyan);
        g.strokePath(waveformPath, juce::PathStrokeType(2.0f));
    }

    // Draw playback position
    if (playbackPosition > 0.0)
    {
        float x = static_cast<float>(playbackPosition) * static_cast<float>(getWidth());
        g.setColour(juce::Colours::red.withAlpha(0.8f));
        g.drawVerticalLine(static_cast<int>(x), 0.0f, static_cast<float>(getHeight()));
    }

    // Draw center line
    g.setColour(juce::Colours::white.withAlpha(0.2f));
    g.drawHorizontalLine(getHeight() / 2, 0.0f, static_cast<float>(getWidth()));

    // Draw grid
    g.setColour(juce::Colours::white.withAlpha(0.1f));
    for (int i = 1; i < 4; ++i)
    {
        float x = (static_cast<float>(i) / 4.0f) * static_cast<float>(getWidth());
        g.drawVerticalLine(static_cast<int>(x), 0.0f, static_cast<float>(getHeight()));
    }
}

void IntelligentSamplerUI::WaveformDisplay::resized()
{
    generateWaveformPath();
}

void IntelligentSamplerUI::WaveformDisplay::mouseWheelMove(const juce::MouseEvent& e, const juce::MouseWheelDetails& wheel)
{
    // Zoom with mouse wheel
    zoomLevel += wheel.deltaY * 0.1;
    zoomLevel = juce::jlimit(0.1, 10.0, zoomLevel);
    generateWaveformPath();
    repaint();
}

void IntelligentSamplerUI::WaveformDisplay::setAudioBuffer(const juce::AudioBuffer<float>& buffer, double sr)
{
    audioBuffer = buffer;
    sampleRate = sr;
    generateWaveformPath();
    repaint();
}

void IntelligentSamplerUI::WaveformDisplay::setPlaybackPosition(double position)
{
    playbackPosition = position;
    repaint();
}

void IntelligentSamplerUI::WaveformDisplay::generateWaveformPath()
{
    waveformPath.clear();

    if (audioBuffer.getNumSamples() == 0)
        return;

    const int numSamples = audioBuffer.getNumSamples();
    const int numChannels = audioBuffer.getNumChannels();
    const int width = getWidth();
    const int height = getHeight();

    waveformPath.startNewSubPath(0.0f, static_cast<float>(height) / 2.0f);

    const int samplesPerPixel = juce::jmax(1, static_cast<int>(static_cast<double>(numSamples) / static_cast<double>(width) / zoomLevel));

    for (int x = 0; x < width; ++x)
    {
        float minValue = 1.0f;
        float maxValue = -1.0f;

        int sampleStart = static_cast<int>((static_cast<double>(x) / static_cast<double>(width)) * static_cast<double>(numSamples) * zoomLevel);
        int sampleEnd = sampleStart + samplesPerPixel;

        if (sampleStart >= numSamples)
            break;

        sampleEnd = juce::jmin(sampleEnd, numSamples);

        for (int channel = 0; channel < numChannels; ++channel)
        {
            auto* channelData = audioBuffer.getReadPointer(channel);
            for (int sample = sampleStart; sample < sampleEnd; ++sample)
            {
                float value = channelData[sample];
                minValue = juce::jmin(minValue, value);
                maxValue = juce::jmax(maxValue, value);
            }
        }

        float yMin = juce::jmap(maxValue, -1.0f, 1.0f, static_cast<float>(height), 0.0f);
        float yMax = juce::jmap(minValue, -1.0f, 1.0f, static_cast<float>(height), 0.0f);

        waveformPath.lineTo(static_cast<float>(x), yMin);
        waveformPath.lineTo(static_cast<float>(x), yMax);
    }

    waveformPath.lineTo(static_cast<float>(width), static_cast<float>(height) / 2.0f);
}

//==============================================================================
// LayerManager Implementation
//==============================================================================

IntelligentSamplerUI::LayerManager::LayerManager()
{
    addAndMakeVisible(table);
    table.setModel(this);
    table.setColour(juce::ListBox::backgroundColourId, juce::Colour(0xff1a1a2e));

    // Add columns
    table.getHeader().addColumn("Name", 1, 150);
    table.getHeader().addColumn("Enabled", 2, 60);
    table.getHeader().addColumn("Volume", 3, 80);
    table.getHeader().addColumn("Pan", 4, 80);
}

IntelligentSamplerUI::LayerManager::~LayerManager() = default;

void IntelligentSamplerUI::LayerManager::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a2e));
}

void IntelligentSamplerUI::LayerManager::resized()
{
    table.setBounds(getLocalBounds());
}

int IntelligentSamplerUI::LayerManager::getNumRows()
{
    return static_cast<int>(layers.size());
}

void IntelligentSamplerUI::LayerManager::paintRowBackground(juce::Graphics& g, int rowNumber, int width, int height, bool rowIsSelected)
{
    if (rowIsSelected)
    {
        g.setColour(juce::Colours::cyan.withAlpha(0.3f));
    }
    else if (rowNumber % 2 == 0)
    {
        g.setColour(juce::Colour(0xff2a2a3e));
    }
    else
    {
        g.setColour(juce::Colour(0xff1a1a2e));
    }

    g.fillRect(0, 0, width, height);
}

void IntelligentSamplerUI::LayerManager::paintCell(juce::Graphics& g, int rowNumber, int columnId,
                                                    int width, int height, bool rowIsSelected)
{
    if (rowNumber >= static_cast<int>(layers.size()))
        return;

    const auto& layer = layers[rowNumber];

    g.setColour(juce::Colours::white);
    g.setFont(12.0f);

    juce::String text;
    switch (columnId)
    {
        case 1: text = layer.name; break;
        case 2: text = layer.enabled ? "Yes" : "No"; break;
        case 3: text = juce::String(layer.volume, 2); break;
        case 4: text = juce::String(layer.pan); break;
        default: break;
    }

    g.drawText(text, 2, 0, width - 4, height, juce::Justification::centredLeft, true);
}

void IntelligentSamplerUI::LayerManager::addLayer(const Layer& layer)
{
    layers.push_back(layer);
    table.updateContent();
}

void IntelligentSamplerUI::LayerManager::removeLayer(int index)
{
    if (index >= 0 && index < static_cast<int>(layers.size()))
    {
        layers.erase(layers.begin() + index);
        table.updateContent();
    }
}

void IntelligentSamplerUI::LayerManager::clearLayers()
{
    layers.clear();
    table.updateContent();
}

//==============================================================================
// MLAnalyzer Implementation
//==============================================================================

IntelligentSamplerUI::MLAnalyzer::MLAnalyzer()
{
    setOpaque(true);
}

IntelligentSamplerUI::MLAnalyzer::~MLAnalyzer() = default;

void IntelligentSamplerUI::MLAnalyzer::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a2e));

    g.setColour(juce::Colours::white);
    g.setFont(14.0f);
    g.drawText("ML Sample Analysis", getLocalBounds().removeFromTop(30),
               juce::Justification::centred, true);

    if (!analysisText.isEmpty())
    {
        g.setFont(12.0f);
        g.drawMultiLineText(analysisText, 10, 50, getWidth() - 20);
    }
}

void IntelligentSamplerUI::MLAnalyzer::resized()
{
    // Layout if needed
}

IntelligentSamplerUI::MLAnalyzer::AnalysisResult
IntelligentSamplerUI::MLAnalyzer::analyzeSample(const juce::AudioBuffer<float>& buffer, double sampleRate)
{
    AnalysisResult result;

    if (buffer.getNumSamples() == 0)
        return result;

    // Detect pitch
    result.fundamentalFrequency = detectPitch(buffer, sampleRate);

    // Calculate estimated root note from frequency
    if (result.fundamentalFrequency > 0.0f)
    {
        float midiNote = 69.0f + 12.0f * std::log2(result.fundamentalFrequency / 440.0f);
        result.estimatedRootNote = juce::roundToInt(midiNote);
    }

    // Calculate brightness (spectral centroid)
    juce::dsp::FFT fft(10); // 1024 points
    std::vector<float> fftData(2048, 0.0f);

    int numSamples = juce::jmin(1024, buffer.getNumSamples());
    for (int i = 0; i < numSamples; ++i)
    {
        fftData[i] = buffer.getSample(0, i);
    }

    fft.performFrequencyOnlyForwardTransform(fftData.data());
    result.brightness = calculateSpectralCentroid(fftData);

    // Calculate attack time (simplified)
    const float attackThreshold = 0.1f;
    result.attack = 0.0f;
    for (int i = 0; i < buffer.getNumSamples(); ++i)
    {
        if (std::abs(buffer.getSample(0, i)) > attackThreshold)
        {
            result.attack = static_cast<float>(i) / static_cast<float>(sampleRate);
            break;
        }
    }

    currentAnalysis = result;
    return result;
}

void IntelligentSamplerUI::MLAnalyzer::displayAnalysis(const AnalysisResult& result)
{
    analysisText = "Fundamental Frequency: " + juce::String(result.fundamentalFrequency, 2) + " Hz\n";
    analysisText += "Estimated Root Note: " + juce::MidiMessage::getMidiNoteName(result.estimatedRootNote, true, true, 3) + "\n";
    analysisText += "Brightness: " + juce::String(result.brightness, 2) + "\n";
    analysisText += "Attack Time: " + juce::String(result.attack * 1000.0f, 2) + " ms\n";

    repaint();
}

float IntelligentSamplerUI::MLAnalyzer::detectPitch(const juce::AudioBuffer<float>& buffer, double sr)
{
    // Simplified autocorrelation-based pitch detection
    int numSamples = juce::jmin(2048, buffer.getNumSamples());
    std::vector<float> autocorr(numSamples, 0.0f);

    // Calculate autocorrelation
    for (int lag = 0; lag < numSamples / 2; ++lag)
    {
        float sum = 0.0f;
        for (int i = 0; i < numSamples - lag; ++i)
        {
            sum += buffer.getSample(0, i) * buffer.getSample(0, i + lag);
        }
        autocorr[lag] = sum;
    }

    // Find first peak after initial peak
    int peakLag = 0;
    float maxValue = 0.0f;
    for (int lag = 20; lag < numSamples / 2; ++lag)
    {
        if (autocorr[lag] > maxValue)
        {
            maxValue = autocorr[lag];
            peakLag = lag;
        }
    }

    if (peakLag > 0)
    {
        return static_cast<float>(sr) / static_cast<float>(peakLag);
    }

    return 0.0f;
}

float IntelligentSamplerUI::MLAnalyzer::calculateSpectralCentroid(const std::vector<float>& spectrum)
{
    float weightedSum = 0.0f;
    float sum = 0.0f;

    for (size_t i = 0; i < spectrum.size() / 2; ++i)
    {
        weightedSum += static_cast<float>(i) * spectrum[i];
        sum += spectrum[i];
    }

    if (sum > 0.0f)
    {
        return weightedSum / sum / (static_cast<float>(spectrum.size()) / 2.0f);
    }

    return 0.0f;
}

//==============================================================================
// VelocityLayerEditor Implementation
//==============================================================================

IntelligentSamplerUI::VelocityLayerEditor::VelocityLayerEditor()
{
    setOpaque(true);
}

IntelligentSamplerUI::VelocityLayerEditor::~VelocityLayerEditor() = default;

void IntelligentSamplerUI::VelocityLayerEditor::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a2e));

    // Draw velocity layers
    for (size_t i = 0; i < layers.size(); ++i)
    {
        const auto& layer = layers[i];

        float y1 = (1.0f - (static_cast<float>(layer.highVelocity) / 127.0f)) * static_cast<float>(getHeight());
        float y2 = (1.0f - (static_cast<float>(layer.lowVelocity) / 127.0f)) * static_cast<float>(getHeight());

        // Layer rectangle
        g.setColour(layer.color.withAlpha(0.3f));
        g.fillRect(0.0f, y1, static_cast<float>(getWidth()), y2 - y1);

        // Layer outline
        g.setColour(layer.color);
        g.drawRect(0.0f, y1, static_cast<float>(getWidth()), y2 - y1, 2.0f);

        // Selected layer highlight
        if (static_cast<int>(i) == selectedLayerIndex)
        {
            g.setColour(juce::Colours::white);
            g.drawRect(0.0f, y1 - 2.0f, static_cast<float>(getWidth()), y2 - y1 + 4.0f, 3.0f);
        }

        // Layer label
        g.setColour(juce::Colours::white);
        g.setFont(12.0f);
        juce::String labelText = juce::String(layer.lowVelocity) + " - " + juce::String(layer.highVelocity);
        g.drawText(labelText, 5, static_cast<int>(y1), 100, 20, juce::Justification::left, true);
    }
}

void IntelligentSamplerUI::VelocityLayerEditor::resized()
{
    // Update layout if needed
}

void IntelligentSamplerUI::VelocityLayerEditor::mouseDown(const juce::MouseEvent& e)
{
    // Select layer on click
    float normalizedY = static_cast<float>(e.y) / static_cast<float>(getHeight());
    int velocity = static_cast<int>((1.0f - normalizedY) * 127.0f);

    selectedLayerIndex = -1;
    for (size_t i = 0; i < layers.size(); ++i)
    {
        if (velocity >= layers[i].lowVelocity && velocity <= layers[i].highVelocity)
        {
            selectedLayerIndex = static_cast<int>(i);
            break;
        }
    }

    repaint();
}

void IntelligentSamplerUI::VelocityLayerEditor::mouseDrag(const juce::MouseEvent& e)
{
    if (selectedLayerIndex >= 0 && selectedLayerIndex < static_cast<int>(layers.size()))
    {
        // Allow dragging to adjust layer boundaries
        repaint();
    }
}

void IntelligentSamplerUI::VelocityLayerEditor::addVelocityLayer(const VelocityLayer& layer)
{
    layers.push_back(layer);
    repaint();
}

void IntelligentSamplerUI::VelocityLayerEditor::clearLayers()
{
    layers.clear();
    selectedLayerIndex = -1;
    repaint();
}

//==============================================================================
// IntelligentSamplerUI Main Implementation
//==============================================================================

IntelligentSamplerUI::IntelligentSamplerUI(juce::AudioProcessorValueTreeState& vts)
    : parameters(vts),
      loadSampleButton("Load Sample"),
      clearButton("Clear All"),
      autoMapButton("Auto Map"),
      exportButton("Export"),
      attackLabel("", "Attack"),
      decayLabel("", "Decay"),
      sustainLabel("", "Sustain"),
      releaseLabel("", "Release"),
      pitchLabel("", "Pitch"),
      volumeLabel("", "Volume"),
      triggerModeLabel("", "Trigger Mode")
{
    // Create sub-components
    zoneEditor = std::make_unique<ZoneEditor>();
    waveformDisplay = std::make_unique<WaveformDisplay>();
    layerManager = std::make_unique<LayerManager>();
    mlAnalyzer = std::make_unique<MLAnalyzer>();
    velocityLayerEditor = std::make_unique<VelocityLayerEditor>();

    addAndMakeVisible(*zoneEditor);
    addAndMakeVisible(*waveformDisplay);
    addAndMakeVisible(*layerManager);
    addAndMakeVisible(*mlAnalyzer);
    addAndMakeVisible(*velocityLayerEditor);

    setupControls();
    applyCustomLookAndFeel();

    startTimer(30); // ~33 FPS
    setSize(1200, 800);
}

IntelligentSamplerUI::~IntelligentSamplerUI()
{
    stopTimer();
}

void IntelligentSamplerUI::paint(juce::Graphics& g)
{
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xff0a0a0f), 0.0f, 0.0f,
        juce::Colour(0xff1a1a2e), static_cast<float>(getWidth()), static_cast<float>(getHeight()), false));
    g.fillAll();

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(24.0f, juce::Font::bold));
    g.drawText("Intelligent Sampler", getLocalBounds().removeFromTop(40),
               juce::Justification::centred, true);
}

void IntelligentSamplerUI::resized()
{
    auto bounds = getLocalBounds();
    bounds.removeFromTop(40); // Title space

    // Top section - waveform and ML analyzer
    auto topSection = bounds.removeFromTop(200);
    waveformDisplay->setBounds(topSection.removeFromLeft(getWidth() * 2 / 3));
    mlAnalyzer->setBounds(topSection);

    // Middle section - zone editor and velocity layer editor
    auto middleSection = bounds.removeFromTop(250);
    zoneEditor->setBounds(middleSection.removeFromLeft(getWidth() * 2 / 3));
    velocityLayerEditor->setBounds(middleSection);

    // Layer manager section
    auto layerSection = bounds.removeFromTop(150);
    layerManager->setBounds(layerSection);

    // Controls section
    auto controlSection = bounds.removeFromTop(100);

    // Buttons row
    auto buttonRow = controlSection.removeFromTop(40);
    loadSampleButton.setBounds(buttonRow.removeFromLeft(120).reduced(5));
    clearButton.setBounds(buttonRow.removeFromLeft(100).reduced(5));
    autoMapButton.setBounds(buttonRow.removeFromLeft(100).reduced(5));
    exportButton.setBounds(buttonRow.removeFromLeft(100).reduced(5));

    // Sliders row
    auto sliderRow = controlSection;
    int sliderWidth = sliderRow.getWidth() / 6;

    attackSlider.setBounds(sliderRow.removeFromLeft(sliderWidth).reduced(5));
    decaySlider.setBounds(sliderRow.removeFromLeft(sliderWidth).reduced(5));
    sustainSlider.setBounds(sliderRow.removeFromLeft(sliderWidth).reduced(5));
    releaseSlider.setBounds(sliderRow.removeFromLeft(sliderWidth).reduced(5));
    pitchSlider.setBounds(sliderRow.removeFromLeft(sliderWidth).reduced(5));
    volumeSlider.setBounds(sliderRow.removeFromLeft(sliderWidth).reduced(5));

    // Combo box
    triggerModeCombo.setBounds(bounds.removeFromTop(30).removeFromLeft(150).reduced(5));
}

void IntelligentSamplerUI::timerCallback()
{
    // Update UI elements periodically
}

bool IntelligentSamplerUI::isInterestedInFileDrag(const juce::StringArray& files)
{
    for (const auto& file : files)
    {
        if (file.endsWithIgnoreCase(".wav") || file.endsWithIgnoreCase(".aiff") ||
            file.endsWithIgnoreCase(".mp3") || file.endsWithIgnoreCase(".flac"))
        {
            return true;
        }
    }
    return false;
}

void IntelligentSamplerUI::filesDropped(const juce::StringArray& files, int x, int y)
{
    for (const auto& filePath : files)
    {
        juce::File file(filePath);
        loadSample(file);
    }
}

void IntelligentSamplerUI::loadSample(const juce::File& file)
{
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    auto reader = std::unique_ptr<juce::AudioFormatReader>(formatManager.createReaderFor(file));
    if (reader != nullptr)
    {
        SampleData sampleData;
        sampleData.name = file.getFileNameWithoutExtension();
        sampleData.sampleRate = reader->sampleRate;
        sampleData.buffer.setSize(static_cast<int>(reader->numChannels), static_cast<int>(reader->lengthInSamples));
        reader->read(&sampleData.buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

        // Analyze sample
        if (mlAnalyzer)
        {
            auto analysis = mlAnalyzer->analyzeSample(sampleData.buffer, sampleData.sampleRate);
            mlAnalyzer->displayAnalysis(analysis);
            sampleData.rootNote = analysis.estimatedRootNote;
        }

        // Assign color
        sampleData.color = juce::Colour::fromHSV(juce::Random::getSystemRandom().nextFloat(), 0.7f, 0.9f, 1.0f);

        loadedSamples.push_back(std::move(sampleData));

        // Update waveform display
        if (waveformDisplay && !loadedSamples.empty())
        {
            waveformDisplay->setAudioBuffer(loadedSamples.back().buffer, loadedSamples.back().sampleRate);
        }

        // Add to layer manager
        if (layerManager)
        {
            LayerManager::Layer layer;
            layer.name = sampleData.name;
            layer.enabled = true;
            layer.volume = 1.0f;
            layer.pan = 0;
            layer.color = sampleData.color;
            layerManager->addLayer(layer);
        }
    }
}

void IntelligentSamplerUI::clearAllSamples()
{
    loadedSamples.clear();
    if (zoneEditor) zoneEditor->clearZones();
    if (layerManager) layerManager->clearLayers();
    if (velocityLayerEditor) velocityLayerEditor->clearLayers();
}

void IntelligentSamplerUI::setupControls()
{
    // Buttons
    addAndMakeVisible(loadSampleButton);
    addAndMakeVisible(clearButton);
    addAndMakeVisible(autoMapButton);
    addAndMakeVisible(exportButton);

    loadSampleButton.onClick = [this]
    {
        juce::FileChooser chooser("Select audio file...", juce::File(), "*.wav;*.aiff;*.mp3;*.flac");
        if (chooser.browseForFileToOpen())
        {
            loadSample(chooser.getResult());
        }
    };

    clearButton.onClick = [this] { clearAllSamples(); };
    autoMapButton.onClick = [this] { analyzeAndCreateZones(); };

    // Sliders
    setupSlider(attackSlider, attackLabel, 0.0, 1.0, 0.01);
    setupSlider(decaySlider, decayLabel, 0.0, 1.0, 0.1);
    setupSlider(sustainSlider, sustainLabel, 0.0, 1.0, 0.8);
    setupSlider(releaseSlider, releaseLabel, 0.0, 2.0, 0.1);
    setupSlider(pitchSlider, pitchLabel, -24.0, 24.0, 0.0);
    setupSlider(volumeSlider, volumeLabel, 0.0, 2.0, 1.0);

    // Combo box
    addAndMakeVisible(triggerModeCombo);
    addAndMakeVisible(triggerModeLabel);
    triggerModeLabel.attachToComponent(&triggerModeCombo, true);

    triggerModeCombo.addItem("Normal", 1);
    triggerModeCombo.addItem("Round Robin", 2);
    triggerModeCombo.addItem("Random", 3);
    triggerModeCombo.setSelectedId(1);
}

void IntelligentSamplerUI::setupSlider(juce::Slider& slider, juce::Label& label,
                                       double min, double max, double defaultValue)
{
    slider.setRange(min, max);
    slider.setValue(defaultValue);
    slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);

    addAndMakeVisible(slider);
    addAndMakeVisible(label);
    label.attachToComponent(&slider, false);
    label.setJustificationType(juce::Justification::centred);
}

void IntelligentSamplerUI::analyzeAndCreateZones()
{
    if (zoneEditor)
    {
        zoneEditor->clearZones();

        for (size_t i = 0; i < loadedSamples.size(); ++i)
        {
            ZoneEditor::Zone zone;
            zone.lowKey = loadedSamples[i].rootNote - 2;
            zone.highKey = loadedSamples[i].rootNote + 2;
            zone.lowVelocity = 0;
            zone.highVelocity = 127;
            zone.color = loadedSamples[i].color;
            zone.sampleName = loadedSamples[i].name;

            zoneEditor->addZone(zone);
        }
    }
}

void IntelligentSamplerUI::applyCustomLookAndFeel()
{
    getLookAndFeel().setColour(juce::Slider::thumbColourId, juce::Colour(0xff00ffff));
    getLookAndFeel().setColour(juce::Slider::rotarySliderFillColourId, juce::Colour(0xff0088cc));
    getLookAndFeel().setColour(juce::Slider::rotarySliderOutlineColourId, juce::Colour(0xff003366));
    getLookAndFeel().setColour(juce::TextButton::buttonColourId, juce::Colour(0xff1a1a2e));
    getLookAndFeel().setColour(juce::TextButton::textColourOffId, juce::Colours::cyan);
}
