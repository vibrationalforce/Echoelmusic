#include "NeuralSoundSynthUI.h"

namespace Echoelmusic {

//==============================================================================
// LatentSpaceVisualizer Implementation
//==============================================================================

LatentSpaceVisualizer::LatentSpaceVisualizer(NeuralSoundSynth& synth)
    : synthesizer(synth)
{
    generateLatentGrid();
    startTimer(30); // 30 FPS
}

LatentSpaceVisualizer::~LatentSpaceVisualizer()
{
    stopTimer();
}

void LatentSpaceVisualizer::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Background gradient
    juce::ColourGradient gradient(
        juce::Colour(0xff1a1a2e), bounds.getX(), bounds.getY(),
        juce::Colour(0xff16213e), bounds.getRight(), bounds.getBottom(),
        false
    );
    g.setGradientFill(gradient);
    g.fillRoundedRectangle(bounds, 10.0f);

    // Border
    g.setColour(juce::Colour(0xff0f3460));
    g.drawRoundedRectangle(bounds.reduced(1.0f), 10.0f, 2.0f);

    // Draw latent grid (background visualization)
    for (size_t i = 0; i < gridPoints.size(); ++i)
    {
        auto point = gridPoints[i];
        auto color = gridColors[i];

        float x = bounds.getX() + point.x * bounds.getWidth();
        float y = bounds.getY() + point.y * bounds.getHeight();

        g.setColour(color.withAlpha(0.3f));
        g.fillEllipse(x - 3.0f, y - 3.0f, 6.0f, 6.0f);
    }

    // Draw position history trail
    if (positionHistory.size() > 1)
    {
        juce::Path trail;
        bool first = true;

        for (size_t i = 0; i < positionHistory.size(); ++i)
        {
            auto pos = positionHistory[i];
            float x = bounds.getX() + pos.x * bounds.getWidth();
            float y = bounds.getY() + pos.y * bounds.getHeight();

            if (first)
            {
                trail.startNewSubPath(x, y);
                first = false;
            }
            else
            {
                trail.lineTo(x, y);
            }
        }

        g.setColour(juce::Colour(0xff00d9ff).withAlpha(0.5f));
        g.strokePath(trail, juce::PathStrokeType(2.0f));
    }

    // Draw current position
    float currentX = bounds.getX() + currentPosition.x * bounds.getWidth();
    float currentY = bounds.getY() + currentPosition.y * bounds.getHeight();

    // Glow effect
    g.setColour(juce::Colour(0xff00d9ff).withAlpha(0.3f));
    g.fillEllipse(currentX - 20.0f, currentY - 20.0f, 40.0f, 40.0f);

    g.setColour(juce::Colour(0xff00d9ff).withAlpha(0.5f));
    g.fillEllipse(currentX - 15.0f, currentY - 15.0f, 30.0f, 30.0f);

    // Center point
    g.setColour(juce::Colour(0xff00d9ff));
    g.fillEllipse(currentX - 8.0f, currentY - 8.0f, 16.0f, 16.0f);

    g.setColour(juce::Colours::white);
    g.fillEllipse(currentX - 4.0f, currentY - 4.0f, 8.0f, 8.0f);

    // Title
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    g.drawText("LATENT SPACE (128D → 2D)",
              bounds.reduced(10.0f).removeFromTop(20),
              juce::Justification::centredTop);
}

void LatentSpaceVisualizer::resized()
{
}

void LatentSpaceVisualizer::timerCallback()
{
    // Smooth interpolation to target position
    currentPosition.x += (targetPosition.x - currentPosition.x) * 0.1f;
    currentPosition.y += (targetPosition.y - currentPosition.y) * 0.1f;

    repaint();
}

void LatentSpaceVisualizer::mouseDown(const juce::MouseEvent& event)
{
    auto bounds = getLocalBounds().toFloat();
    float x = (event.position.x - bounds.getX()) / bounds.getWidth();
    float y = (event.position.y - bounds.getY()) / bounds.getHeight();

    targetPosition = {juce::jlimit(0.0f, 1.0f, x),
                     juce::jlimit(0.0f, 1.0f, y)};

    updateLatentPosition(targetPosition);
}

void LatentSpaceVisualizer::mouseDrag(const juce::MouseEvent& event)
{
    mouseDown(event); // Same as mouse down for continuous dragging
}

void LatentSpaceVisualizer::mouseUp(const juce::MouseEvent& event)
{
    // Add to history
    positionHistory.push_back(currentPosition);
    if (positionHistory.size() > maxHistorySize)
        positionHistory.pop_front();
}

void LatentSpaceVisualizer::updateLatentPosition(juce::Point<float> position)
{
    // Map 2D position to 128D latent vector (simplified PCA inverse)
    // In real implementation, this would use learned PCA components
    std::vector<float> latentVector(128);

    // Simple mapping: first 2 dimensions are direct, rest are interpolated
    latentVector[0] = (position.x - 0.5f) * 4.0f; // Range: -2 to +2
    latentVector[1] = (position.y - 0.5f) * 4.0f;

    // Fill remaining dimensions with smooth interpolation
    for (int i = 2; i < 128; ++i)
    {
        float phase = (float)i / 128.0f * juce::MathConstants<float>::twoPi;
        latentVector[i] = std::sin(phase + position.x) * std::cos(phase + position.y);
    }

    // Update synthesizer (would need to add this method to NeuralSoundSynth)
    // synthesizer.setLatentVector(latentVector);
}

void LatentSpaceVisualizer::generateLatentGrid()
{
    gridPoints.clear();
    gridColors.clear();

    // Generate a grid of points with colors representing latent space regions
    for (int y = 0; y < 20; ++y)
    {
        for (int x = 0; x < 20; ++x)
        {
            float px = (float)x / 19.0f;
            float py = (float)y / 19.0f;

            gridPoints.push_back({px, py});

            // Color based on position (representing different sound regions)
            float hue = px * 0.5f + py * 0.5f;
            gridColors.push_back(juce::Colour::fromHSV(hue, 0.7f, 0.8f, 1.0f));
        }
    }
}

//==============================================================================
// BioDataVisualizer Implementation
//==============================================================================

BioDataVisualizer::BioDataVisualizer()
{
    startTimer(16); // ~60 FPS
}

BioDataVisualizer::~BioDataVisualizer()
{
    stopTimer();
}

void BioDataVisualizer::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Background
    g.setColour(juce::Colour(0xff1a1a2e));
    g.fillRoundedRectangle(bounds, 8.0f);

    // Divide into three sections
    float sectionHeight = bounds.getHeight() / 3.0f;

    hrvRect = bounds.removeFromTop(sectionHeight).reduced(10.0f);
    coherenceRect = bounds.removeFromTop(sectionHeight).reduced(10.0f);
    breathRect = bounds.reduced(10.0f);

    // Draw HRV
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.setFont(juce::Font(12.0f, juce::Font::bold));
    g.drawText("HRV: " + juce::String(currentHRV, 1) + " ms",
              hrvRect.removeFromTop(15), juce::Justification::left);

    drawWaveform(g, hrvHistory, hrvRect, juce::Colour(0xffff6b6b), 20.0f, 100.0f);

    // Draw Coherence
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.drawText("Coherence: " + juce::String(currentCoherence, 2),
              coherenceRect.removeFromTop(15), juce::Justification::left);

    drawWaveform(g, coherenceHistory, coherenceRect, juce::Colour(0xff4ecdc4), 0.0f, 1.0f);

    // Draw Breath
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.drawText("Breath: " + juce::String(currentBreath, 2),
              breathRect.removeFromTop(15), juce::Justification::left);

    drawWaveform(g, breathHistory, breathRect, juce::Colour(0xff95e1d3), 0.0f, 1.0f);
}

void BioDataVisualizer::resized()
{
}

void BioDataVisualizer::timerCallback()
{
    // Simulate bio-data updates (in real implementation, would read from sensor)
    currentHRV = 50.0f + 30.0f * std::sin(juce::Time::getMillisecondCounterHiRes() / 1000.0);
    currentCoherence = 0.5f + 0.3f * std::cos(juce::Time::getMillisecondCounterHiRes() / 2000.0);
    currentBreath = 0.5f + 0.4f * std::sin(juce::Time::getMillisecondCounterHiRes() / 3000.0);

    updateBioData(currentHRV, currentCoherence, currentBreath);
    repaint();
}

void BioDataVisualizer::updateBioData(float hrv, float coherence, float breath)
{
    hrvHistory.push_back(hrv);
    if (hrvHistory.size() > maxHistorySize)
        hrvHistory.pop_front();

    coherenceHistory.push_back(coherence);
    if (coherenceHistory.size() > maxHistorySize)
        coherenceHistory.pop_front();

    breathHistory.push_back(breath);
    if (breathHistory.size() > maxHistorySize)
        breathHistory.pop_front();
}

void BioDataVisualizer::drawWaveform(juce::Graphics& g,
                                    const std::deque<float>& data,
                                    juce::Rectangle<float> bounds,
                                    juce::Colour color,
                                    float minVal, float maxVal)
{
    if (data.empty() || bounds.isEmpty())
        return;

    // Draw background
    g.setColour(juce::Colour(0xff0f3460).withAlpha(0.3f));
    g.fillRoundedRectangle(bounds, 4.0f);

    // Draw waveform
    juce::Path path;
    bool first = true;

    int displaySamples = std::min((int)data.size(), (int)bounds.getWidth());
    int skip = std::max(1, (int)data.size() / displaySamples);

    for (size_t i = 0; i < data.size(); i += skip)
    {
        float value = data[i];
        float normalized = (value - minVal) / (maxVal - minVal);
        normalized = juce::jlimit(0.0f, 1.0f, normalized);

        float x = bounds.getX() + (float)i / data.size() * bounds.getWidth();
        float y = bounds.getBottom() - normalized * bounds.getHeight();

        if (first)
        {
            path.startNewSubPath(x, y);
            first = false;
        }
        else
        {
            path.lineTo(x, y);
        }
    }

    // Glow effect
    g.setColour(color.withAlpha(0.3f));
    g.strokePath(path, juce::PathStrokeType(3.0f));

    g.setColour(color);
    g.strokePath(path, juce::PathStrokeType(2.0f));
}

//==============================================================================
// WaveformVisualizer Implementation
//==============================================================================

WaveformVisualizer::WaveformVisualizer()
{
    waveformBuffer.resize(bufferSize, 0.0f);
    std::fill(fftData.begin(), fftData.end(), 0.0f);
    startTimer(33); // ~30 FPS
}

WaveformVisualizer::~WaveformVisualizer()
{
    stopTimer();
}

void WaveformVisualizer::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Background
    g.setColour(juce::Colour(0xff1a1a2e));
    g.fillRoundedRectangle(bounds, 8.0f);

    // Split view: waveform on top, spectrum on bottom
    auto waveformBounds = bounds.removeFromTop(bounds.getHeight() * 0.5f).reduced(10.0f);
    auto spectrumBounds = bounds.reduced(10.0f);

    drawWaveform(g, waveformBounds);
    drawSpectrum(g, spectrumBounds);
}

void WaveformVisualizer::resized()
{
}

void WaveformVisualizer::timerCallback()
{
    repaint();
}

void WaveformVisualizer::pushAudioSample(float sample)
{
    waveformBuffer[bufferWritePosition] = sample;
    bufferWritePosition = (bufferWritePosition + 1) % bufferSize;
}

void WaveformVisualizer::pushAudioBuffer(const juce::AudioBuffer<float>& buffer)
{
    for (int i = 0; i < buffer.getNumSamples(); ++i)
    {
        pushAudioSample(buffer.getSample(0, i));
    }
}

void WaveformVisualizer::drawWaveform(juce::Graphics& g, juce::Rectangle<float> bounds)
{
    // Background
    g.setColour(juce::Colour(0xff0f3460).withAlpha(0.3f));
    g.fillRoundedRectangle(bounds, 4.0f);

    // Center line
    float centerY = bounds.getCentreY();
    g.setColour(juce::Colour(0xff0f3460));
    g.drawLine(bounds.getX(), centerY, bounds.getRight(), centerY, 1.0f);

    // Waveform path
    juce::Path path;
    bool first = true;

    for (int i = 0; i < bufferSize; ++i)
    {
        float sample = waveformBuffer[(bufferWritePosition + i) % bufferSize];
        float x = bounds.getX() + (float)i / bufferSize * bounds.getWidth();
        float y = centerY - sample * bounds.getHeight() * 0.4f;

        if (first)
        {
            path.startNewSubPath(x, y);
            first = false;
        }
        else
        {
            path.lineTo(x, y);
        }
    }

    // Draw waveform with glow
    g.setColour(juce::Colour(0xff00d9ff).withAlpha(0.5f));
    g.strokePath(path, juce::PathStrokeType(3.0f));

    g.setColour(juce::Colour(0xff00d9ff));
    g.strokePath(path, juce::PathStrokeType(1.5f));

    // Label
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.setFont(juce::Font(12.0f, juce::Font::bold));
    g.drawText("WAVEFORM", bounds.removeFromTop(15), juce::Justification::left);
}

void WaveformVisualizer::drawSpectrum(juce::Graphics& g, juce::Rectangle<float> bounds)
{
    // Background
    g.setColour(juce::Colour(0xff0f3460).withAlpha(0.3f));
    g.fillRoundedRectangle(bounds, 4.0f);

    // Perform FFT (simplified - in real implementation would use proper windowing)
    // For now, draw a placeholder spectrum

    g.setColour(juce::Colour(0xff95e1d3));
    for (int i = 0; i < 100; ++i)
    {
        float frequency = (float)i / 100.0f;
        float magnitude = std::exp(-frequency * 5.0f) + 0.1f;

        float x = bounds.getX() + frequency * bounds.getWidth();
        float barHeight = magnitude * bounds.getHeight();

        g.fillRect(x, bounds.getBottom() - barHeight, bounds.getWidth() / 100.0f, barHeight);
    }

    // Label
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.setFont(juce::Font(12.0f, juce::Font::bold));
    g.drawText("SPECTRUM", bounds.removeFromTop(15), juce::Justification::left);
}

//==============================================================================
// PresetBrowser Implementation
//==============================================================================

PresetBrowser::PresetBrowser()
{
    addAndMakeVisible(presetList);
    presetList.setModel(this);
    presetList.setRowHeight(30);

    addAndMakeVisible(searchBox);
    searchBox.setTextToShowWhenEmpty("Search presets...", juce::Colours::grey);

    addAndMakeVisible(categoryFilter);
    categoryFilter.addItem("All Categories", 1);
    categoryFilter.addItem("Pads", 2);
    categoryFilter.addItem("Leads", 3);
    categoryFilter.addItem("Bass", 4);
    categoryFilter.addItem("Experimental", 5);
    categoryFilter.setSelectedId(1);
}

PresetBrowser::~PresetBrowser()
{
}

void PresetBrowser::paint(juce::Graphics& g)
{
    g.setColour(juce::Colour(0xff1a1a2e));
    g.fillRoundedRectangle(getLocalBounds().toFloat(), 8.0f);
}

void PresetBrowser::resized()
{
    auto bounds = getLocalBounds().reduced(10);

    auto topRow = bounds.removeFromTop(30);
    searchBox.setBounds(topRow.removeFromLeft(bounds.getWidth() * 0.6f));
    topRow.removeFromLeft(10);
    categoryFilter.setBounds(topRow);

    bounds.removeFromTop(10);
    presetList.setBounds(bounds);
}

int PresetBrowser::getNumRows()
{
    return (int)filteredPresets.size();
}

void PresetBrowser::paintListBoxItem(int rowNumber, juce::Graphics& g,
                                     int width, int height, bool rowIsSelected)
{
    if (rowNumber < 0 || rowNumber >= (int)filteredPresets.size())
        return;

    const auto& preset = filteredPresets[rowNumber];

    if (rowIsSelected)
        g.fillAll(juce::Colour(0xff0f3460));
    else
        g.fillAll(juce::Colour(0xff16213e));

    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    g.drawText(preset.name, 10, 2, width - 20, height / 2, juce::Justification::left);

    g.setColour(juce::Colours::white.withAlpha(0.6f));
    g.setFont(juce::Font(11.0f));
    g.drawText(preset.description, 10, height / 2, width - 20, height / 2, juce::Justification::left);
}

void PresetBrowser::listBoxItemClicked(int row, const juce::MouseEvent&)
{
    selectedRow = row;
    // Load preset here
}

void PresetBrowser::loadPresets(const juce::File& presetDirectory)
{
    allPresets.clear();

    auto presetFiles = presetDirectory.findChildFiles(juce::File::findFiles, false, "*.echopreset");

    for (const auto& file : presetFiles)
    {
        PresetInfo info;
        info.name = file.getFileNameWithoutExtension();
        info.category = "Unknown";
        info.description = "Neural synthesis preset";
        info.file = file;

        allPresets.push_back(info);
    }

    filterPresets();
}

juce::String PresetBrowser::getSelectedPreset() const
{
    if (selectedRow >= 0 && selectedRow < (int)filteredPresets.size())
        return filteredPresets[selectedRow].file.getFullPathName();

    return {};
}

void PresetBrowser::filterPresets()
{
    filteredPresets = allPresets;
    presetList.updateContent();
    repaint();
}

//==============================================================================
// Main NeuralSoundSynthUI Implementation
//==============================================================================

NeuralSoundSynthUI::NeuralSoundSynthUI(NeuralSoundSynth& synth)
    : synthesizer(synth)
{
    // Create visualizers
    latentSpaceViz = std::make_unique<LatentSpaceVisualizer>(synthesizer);
    addAndMakeVisible(*latentSpaceViz);

    bioDataViz = std::make_unique<BioDataVisualizer>();
    addAndMakeVisible(*bioDataViz);

    waveformViz = std::make_unique<WaveformVisualizer>();
    addAndMakeVisible(*waveformViz);

    presetBrowser = std::make_unique<PresetBrowser>();
    addAndMakeVisible(*presetBrowser);

    createParameterControls();
    createLabels();

    setSize(1200, 800);
}

NeuralSoundSynthUI::~NeuralSoundSynthUI()
{
}

void NeuralSoundSynthUI::paint(juce::Graphics& g)
{
    // Background gradient
    juce::ColourGradient gradient(
        juce::Colour(0xff0f0f1e), 0.0f, 0.0f,
        juce::Colour(0xff1a1a2e), 0.0f, (float)getHeight(),
        false
    );
    g.setGradientFill(gradient);
    g.fillAll();

    // Title background
    auto titleBounds = getLocalBounds().removeFromTop(60);
    g.setColour(juce::Colour(0xff16213e).withAlpha(0.8f));
    g.fillRect(titleBounds);
}

void NeuralSoundSynthUI::resized()
{
    layoutComponents();
}

void NeuralSoundSynthUI::sliderValueChanged(juce::Slider* slider)
{
    // Update synthesizer parameters
    if (slider == &latentDim1Slider)
    {
        // Update latent dimension 1
    }
    else if (slider == &latentDim2Slider)
    {
        // Update latent dimension 2
    }
    else if (slider == &temperatureSlider)
    {
        // Update temperature parameter
    }
    else if (slider == &morphSpeedSlider)
    {
        // Update morph speed
    }
}

void NeuralSoundSynthUI::buttonClicked(juce::Button* button)
{
    if (button == &loadPresetButton)
    {
        // Show preset browser
    }
    else if (button == &savePresetButton)
    {
        // Save current preset
    }
    else if (button == &randomizeButton)
    {
        // Randomize latent vector
    }
}

void NeuralSoundSynthUI::createParameterControls()
{
    // Latent dimension sliders
    latentDim1Slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    latentDim1Slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    latentDim1Slider.setRange(-2.0, 2.0, 0.01);
    latentDim1Slider.setValue(0.0);
    latentDim1Slider.addListener(this);
    addAndMakeVisible(latentDim1Slider);

    latentDim2Slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    latentDim2Slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    latentDim2Slider.setRange(-2.0, 2.0, 0.01);
    latentDim2Slider.setValue(0.0);
    latentDim2Slider.addListener(this);
    addAndMakeVisible(latentDim2Slider);

    temperatureSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    temperatureSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    temperatureSlider.setRange(0.0, 2.0, 0.01);
    temperatureSlider.setValue(1.0);
    temperatureSlider.addListener(this);
    addAndMakeVisible(temperatureSlider);

    morphSpeedSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    morphSpeedSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    morphSpeedSlider.setRange(0.0, 1.0, 0.01);
    morphSpeedSlider.setValue(0.5);
    morphSpeedSlider.addListener(this);
    addAndMakeVisible(morphSpeedSlider);

    // Synth mode combo
    synthModeCombo.addItem("Harmonic", 1);
    synthModeCombo.addItem("Percussive", 2);
    synthModeCombo.addItem("Texture", 3);
    synthModeCombo.addItem("Hybrid", 4);
    synthModeCombo.setSelectedId(1);
    addAndMakeVisible(synthModeCombo);

    // Bio-reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive");
    bioReactiveToggle.setToggleState(true, juce::dontSendNotification);
    addAndMakeVisible(bioReactiveToggle);

    // Buttons
    loadPresetButton.setButtonText("Load Preset");
    loadPresetButton.addListener(this);
    addAndMakeVisible(loadPresetButton);

    savePresetButton.setButtonText("Save Preset");
    savePresetButton.addListener(this);
    addAndMakeVisible(savePresetButton);

    randomizeButton.setButtonText("Randomize");
    randomizeButton.addListener(this);
    addAndMakeVisible(randomizeButton);
}

void NeuralSoundSynthUI::createLabels()
{
    titleLabel.setText("NEURALSOUNDSYNTH - Bio-Reactive Neural Synthesis",
                      juce::dontSendNotification);
    titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));
    titleLabel.setJustificationType(juce::Justification::centred);
    titleLabel.setColour(juce::Label::textColourId, juce::Colours::white);
    addAndMakeVisible(titleLabel);

    // Create parameter labels
    auto createLabel = [this](const juce::String& text) {
        auto label = std::make_unique<juce::Label>();
        label->setText(text, juce::dontSendNotification);
        label->setFont(juce::Font(12.0f));
        label->setJustificationType(juce::Justification::centred);
        label->setColour(juce::Label::textColourId, juce::Colours::white);
        addAndMakeVisible(*label);
        return label;
    };

    paramLabels.push_back(createLabel("Latent X"));
    paramLabels.push_back(createLabel("Latent Y"));
    paramLabels.push_back(createLabel("Temperature"));
    paramLabels.push_back(createLabel("Morph Speed"));
}

void NeuralSoundSynthUI::layoutComponents()
{
    auto bounds = getLocalBounds();

    // Title
    titleLabel.setBounds(bounds.removeFromTop(60));

    bounds.removeFromTop(10); // Padding

    // Main area split: left visualizers, right controls
    auto leftPanel = bounds.removeFromLeft(bounds.getWidth() * 0.7f);
    auto rightPanel = bounds;

    // Left panel: latent space (top), waveform (bottom)
    latentSpaceViz->setBounds(leftPanel.removeFromTop(leftPanel.getHeight() * 0.6f).reduced(10));
    leftPanel.removeFromTop(10);
    waveformViz->setBounds(leftPanel.reduced(10));

    // Right panel: bio-data (top), controls (middle), presets (bottom)
    rightPanel.removeFromLeft(10); // Padding
    bioDataViz->setBounds(rightPanel.removeFromTop(200).reduced(10));

    rightPanel.removeFromTop(20);

    // Control section
    auto controlBounds = rightPanel.removeFromTop(300).reduced(10);

    // 4 rotary knobs in grid
    auto knobRow1 = controlBounds.removeFromTop(120);
    auto knobRow2 = controlBounds.removeFromTop(120);

    paramLabels[0]->setBounds(knobRow1.removeFromLeft(90).removeFromTop(15));
    latentDim1Slider.setBounds(knobRow1.removeFromLeft(90));

    knobRow1.removeFromLeft(10);
    paramLabels[1]->setBounds(knobRow1.removeFromLeft(90).removeFromTop(15));
    latentDim2Slider.setBounds(knobRow1.removeFromLeft(90));

    paramLabels[2]->setBounds(knobRow2.removeFromLeft(90).removeFromTop(15));
    temperatureSlider.setBounds(knobRow2.removeFromLeft(90));

    knobRow2.removeFromLeft(10);
    paramLabels[3]->setBounds(knobRow2.removeFromLeft(90).removeFromTop(15));
    morphSpeedSlider.setBounds(knobRow2.removeFromLeft(90));

    controlBounds.removeFromTop(10);

    synthModeCombo.setBounds(controlBounds.removeFromTop(30).reduced(5));
    controlBounds.removeFromTop(5);
    bioReactiveToggle.setBounds(controlBounds.removeFromTop(30).reduced(5));

    // Buttons
    rightPanel.removeFromTop(20);
    auto buttonBounds = rightPanel.removeFromTop(100).reduced(10);

    loadPresetButton.setBounds(buttonBounds.removeFromTop(30));
    buttonBounds.removeFromTop(5);
    savePresetButton.setBounds(buttonBounds.removeFromTop(30));
    buttonBounds.removeFromTop(5);
    randomizeButton.setBounds(buttonBounds.removeFromTop(30));

    // Preset browser
    rightPanel.removeFromTop(10);
    presetBrowser->setBounds(rightPanel.reduced(10));
}

} // namespace Echoelmusic
