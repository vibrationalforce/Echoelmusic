#include "AdvancedSculptingUI.h"

//==============================================================================
// AdvancedSculptingUI Implementation
//==============================================================================

AdvancedSculptingUI::AdvancedSculptingUI()
{
    // Create sub-components
    modeSelector = std::make_unique<ModeSelector>(*this);
    addAndMakeVisible(*modeSelector);

    spectralVisualizer = std::make_unique<SpectralVisualizer>(*this);
    addAndMakeVisible(*spectralVisualizer);

    waveformVisualizer = std::make_unique<WaveformVisualizer>(*this);
    addAndMakeVisible(*waveformVisualizer);

    granularPanel = std::make_unique<GranularPanel>(*this);
    addAndMakeVisible(*granularPanel);

    spectralPanel = std::make_unique<SpectralPanel>(*this);
    addAndMakeVisible(*spectralPanel);

    bioStatusPanel = std::make_unique<BioStatusPanel>(*this);
    addAndMakeVisible(*bioStatusPanel);

    // Setup mode change callback
    modeSelector->onModeChanged = [this](SpectralSculptor::ProcessingMode mode)
    {
        currentMode = mode;
        spectralPanel->updateForMode(mode);

        if (spectralSculptor)
        {
            spectralSculptor->setProcessingMode(mode);
        }
    };

    // Start update timer (30 Hz for smooth visualization)
    startTimer(33);
}

AdvancedSculptingUI::~AdvancedSculptingUI()
{
    stopTimer();
}

void AdvancedSculptingUI::setSpectralSculptor(SpectralSculptor* sculptor)
{
    spectralSculptor = sculptor;

    if (spectralSculptor)
    {
        // Sync UI with current sculptor state
        currentMode = spectralSculptor->getProcessingMode();
        modeSelector->setCurrentMode(currentMode);
        spectralPanel->updateForMode(currentMode);
    }
}

void AdvancedSculptingUI::paint(juce::Graphics& g)
{
    // Dark professional background
    g.fillAll(juce::Colour(0xff1a1a1a));

    // Header section
    auto headerBounds = getLocalBounds().removeFromTop(60);
    g.setColour(juce::Colour(0xff252525));
    g.fillRect(headerBounds);

    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(24.0f, juce::Font::bold));
    g.drawText("Advanced Sculpting & Granular",
               headerBounds.reduced(20, 0),
               juce::Justification::centredLeft);

    // Bio-reactive indicator
    if (spectralSculptor && spectralSculptor->isBioReactiveEnabled())
    {
        g.setColour(juce::Colour(0xff00ff88));
        g.fillEllipse(getWidth() - 50.0f, headerBounds.getCentreY() - 5.0f, 10.0f, 10.0f);
        g.setFont(12.0f);
        g.drawText("BIO", getWidth() - 85, headerBounds.getCentreY() - 8, 30, 16,
                   juce::Justification::centred);
    }
}

void AdvancedSculptingUI::resized()
{
    auto bounds = getLocalBounds();

    // Header (60px)
    bounds.removeFromTop(60);

    // Mode selector bar (50px)
    modeSelector->setBounds(bounds.removeFromTop(50));

    bounds.removeFromTop(10); // Spacing

    // Main layout: Left panel (visualizers) + Right panel (controls)
    auto leftPanel = bounds.removeFromLeft(bounds.getWidth() * 0.6f);
    bounds.removeFromLeft(10); // Spacing
    auto rightPanel = bounds;

    // Left panel: Spectral visualizer (70%) + Waveform (30%)
    auto spectralBounds = leftPanel.removeFromTop(leftPanel.getHeight() * 0.7f);
    leftPanel.removeFromTop(10); // Spacing
    spectralVisualizer->setBounds(spectralBounds);
    waveformVisualizer->setBounds(leftPanel);

    // Right panel: Granular (40%) + Spectral (40%) + Bio (20%)
    auto granularBounds = rightPanel.removeFromTop(rightPanel.getHeight() * 0.4f);
    rightPanel.removeFromTop(10);
    auto spectralBounds2 = rightPanel.removeFromTop(rightPanel.getHeight() * 0.5f);
    rightPanel.removeFromTop(10);

    granularPanel->setBounds(granularBounds);
    spectralPanel->setBounds(spectralBounds2);
    bioStatusPanel->setBounds(rightPanel);
}

void AdvancedSculptingUI::timerCallback()
{
    if (!spectralSculptor)
        return;

    // Update spectral visualizer with current FFT data
    auto spectrum = spectralSculptor->getCurrentSpectrum();
    if (!spectrum.empty())
    {
        spectralVisualizer->updateSpectrum(spectrum);
    }

    // Update bio-reactive data
    auto bioData = spectralSculptor->getBioReactiveData();
    bioStatusPanel->updateBioData(bioData.hrv, bioData.coherence, bioData.stress);
}

//==============================================================================
// ModeSelector Implementation
//==============================================================================

AdvancedSculptingUI::ModeSelector::ModeSelector(AdvancedSculptingUI& parent)
    : owner(parent)
{
    // Setup mode buttons
    auto setupButton = [this](juce::TextButton& button, const juce::String& name,
                              SpectralSculptor::ProcessingMode mode)
    {
        button.setButtonText(name);
        button.setClickingTogglesState(true);
        button.setRadioGroupId(1001);
        button.onClick = [this, mode]()
        {
            setCurrentMode(mode);
            if (onModeChanged)
                onModeChanged(mode);
        };
        addAndMakeVisible(button);
    };

    setupButton(denoiseButton, "Denoise", SpectralSculptor::ProcessingMode::Denoise);
    setupButton(gateButton, "Gate", SpectralSculptor::ProcessingMode::Gate);
    setupButton(enhanceButton, "Enhance", SpectralSculptor::ProcessingMode::Enhance);
    setupButton(freezeButton, "Freeze", SpectralSculptor::ProcessingMode::Freeze);
    setupButton(morphButton, "Morph", SpectralSculptor::ProcessingMode::Morph);
    setupButton(restoreButton, "Restore", SpectralSculptor::ProcessingMode::Restore);

    // Set initial mode
    denoiseButton.setToggleState(true, juce::dontSendNotification);
}

void AdvancedSculptingUI::ModeSelector::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff202020));

    // Highlight active mode
    auto bounds = getLocalBounds();
    int buttonWidth = bounds.getWidth() / 6;
    int activeIndex = static_cast<int>(currentMode);

    g.setColour(juce::Colour(0xff3a7bd5).withAlpha(0.3f));
    g.fillRect(activeIndex * buttonWidth, 0, buttonWidth, bounds.getHeight());
}

void AdvancedSculptingUI::ModeSelector::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    int buttonWidth = bounds.getWidth() / 6;

    denoiseButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    gateButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    enhanceButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    freezeButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    morphButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    restoreButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
}

void AdvancedSculptingUI::ModeSelector::setCurrentMode(SpectralSculptor::ProcessingMode mode)
{
    currentMode = mode;

    // Update button states
    denoiseButton.setToggleState(mode == SpectralSculptor::ProcessingMode::Denoise, juce::dontSendNotification);
    gateButton.setToggleState(mode == SpectralSculptor::ProcessingMode::Gate, juce::dontSendNotification);
    enhanceButton.setToggleState(mode == SpectralSculptor::ProcessingMode::Enhance, juce::dontSendNotification);
    freezeButton.setToggleState(mode == SpectralSculptor::ProcessingMode::Freeze, juce::dontSendNotification);
    morphButton.setToggleState(mode == SpectralSculptor::ProcessingMode::Morph, juce::dontSendNotification);
    restoreButton.setToggleState(mode == SpectralSculptor::ProcessingMode::Restore, juce::dontSendNotification);

    repaint();
}

//==============================================================================
// SpectralVisualizer Implementation
//==============================================================================

AdvancedSculptingUI::SpectralVisualizer::SpectralVisualizer(AdvancedSculptingUI& parent)
    : owner(parent)
{
    // Initialize spectrum buffers (2048 bins typical)
    currentSpectrum.resize(2048, 0.0f);
    displaySpectrum.resize(2048, 0.0f);

    // Start smoothing timer (60 Hz for ultra-smooth display)
    startTimer(16);
}

AdvancedSculptingUI::SpectralVisualizer::~SpectralVisualizer()
{
    stopTimer();
}

void AdvancedSculptingUI::SpectralVisualizer::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.fillAll(juce::Colour(0xff0a0a0a));

    // Grid lines
    g.setColour(juce::Colour(0xff2a2a2a));

    // Horizontal grid (dB levels)
    for (int db = -60; db <= 0; db += 12)
    {
        float y = juce::jmap(static_cast<float>(db), minDb, maxDb,
                            static_cast<float>(bounds.getBottom()),
                            static_cast<float>(bounds.getY()));
        g.drawHorizontalLine(static_cast<int>(y),
                            static_cast<float>(bounds.getX()),
                            static_cast<float>(bounds.getRight()));

        // dB label
        g.setColour(juce::Colour(0xff505050));
        g.setFont(10.0f);
        g.drawText(juce::String(db) + " dB", bounds.getX() + 5, static_cast<int>(y) - 6, 50, 12,
                   juce::Justification::left);
        g.setColour(juce::Colour(0xff2a2a2a));
    }

    // Vertical grid (frequency markers)
    for (int freq : {100, 500, 1000, 5000, 10000})
    {
        // Log-scale mapping for frequency
        float normalizedFreq = std::log10(static_cast<float>(freq) / 20.0f) / std::log10(20000.0f / 20.0f);
        float x = bounds.getX() + normalizedFreq * bounds.getWidth();
        g.drawVerticalLine(static_cast<int>(x),
                          static_cast<float>(bounds.getY()),
                          static_cast<float>(bounds.getBottom()));

        // Frequency label
        g.setColour(juce::Colour(0xff505050));
        g.setFont(10.0f);
        juce::String freqLabel = freq >= 1000 ? juce::String(freq / 1000) + "k" : juce::String(freq);
        g.drawText(freqLabel, static_cast<int>(x) - 15, bounds.getBottom() - 15, 30, 12,
                   juce::Justification::centred);
        g.setColour(juce::Colour(0xff2a2a2a));
    }

    // Reference spectrum (if available)
    if (hasReference && !referenceSpectrum.empty())
    {
        juce::Path referencePath;
        bool firstPoint = true;

        for (size_t i = 0; i < referenceSpectrum.size(); ++i)
        {
            float normalizedFreq = static_cast<float>(i) / static_cast<float>(referenceSpectrum.size());
            float x = bounds.getX() + normalizedFreq * bounds.getWidth();
            float db = juce::Decibels::gainToDecibels(referenceSpectrum[i] + 1e-9f);
            float y = juce::jmap(db, minDb, maxDb,
                                static_cast<float>(bounds.getBottom()),
                                static_cast<float>(bounds.getY()));

            if (firstPoint)
            {
                referencePath.startNewSubPath(x, y);
                firstPoint = false;
            }
            else
            {
                referencePath.lineTo(x, y);
            }
        }

        g.setColour(juce::Colour(0xff666666).withAlpha(0.5f));
        g.strokePath(referencePath, juce::PathStrokeType(1.0f));
    }

    // Current spectrum
    if (!displaySpectrum.empty())
    {
        juce::Path spectrumPath;
        bool firstPoint = true;

        for (size_t i = 0; i < displaySpectrum.size(); ++i)
        {
            float normalizedFreq = static_cast<float>(i) / static_cast<float>(displaySpectrum.size());
            float x = bounds.getX() + normalizedFreq * bounds.getWidth();
            float db = juce::Decibels::gainToDecibels(displaySpectrum[i] + 1e-9f);
            float y = juce::jmap(db, minDb, maxDb,
                                static_cast<float>(bounds.getBottom()),
                                static_cast<float>(bounds.getY()));

            if (firstPoint)
            {
                spectrumPath.startNewSubPath(x, y);
                firstPoint = false;
            }
            else
            {
                spectrumPath.lineTo(x, y);
            }
        }

        // Gradient fill
        juce::ColourGradient gradient(juce::Colour(0xff3a7bd5).withAlpha(0.6f),
                                     bounds.getX(), bounds.getY(),
                                     juce::Colour(0xff00d2ff).withAlpha(0.6f),
                                     bounds.getRight(), bounds.getBottom(),
                                     false);
        g.setGradientFill(gradient);

        // Fill area under curve
        juce::Path fillPath = spectrumPath;
        fillPath.lineTo(bounds.getRight(), bounds.getBottom());
        fillPath.lineTo(bounds.getX(), bounds.getBottom());
        fillPath.closeSubPath();
        g.fillPath(fillPath);

        // Stroke outline
        g.setColour(juce::Colour(0xff00d2ff));
        g.strokePath(spectrumPath, juce::PathStrokeType(2.0f));
    }

    // Border
    g.setColour(juce::Colour(0xff404040));
    g.drawRect(bounds, 1);

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    g.drawText("Spectral Analysis (FFT 2048)", bounds.getX() + 10, bounds.getY() + 10, 200, 20,
               juce::Justification::left);
}

void AdvancedSculptingUI::SpectralVisualizer::resized()
{
    // Nothing to resize (no child components)
}

void AdvancedSculptingUI::SpectralVisualizer::updateSpectrum(const std::vector<float>& spectrum)
{
    if (spectrum.size() != currentSpectrum.size())
        currentSpectrum.resize(spectrum.size());

    currentSpectrum = spectrum;
}

void AdvancedSculptingUI::SpectralVisualizer::setReferenceSpectrum(const std::vector<float>& spectrum)
{
    referenceSpectrum = spectrum;
    hasReference = true;
}

void AdvancedSculptingUI::SpectralVisualizer::clearReference()
{
    hasReference = false;
    referenceSpectrum.clear();
}

void AdvancedSculptingUI::SpectralVisualizer::timerCallback()
{
    // Smooth display spectrum towards current spectrum
    for (size_t i = 0; i < currentSpectrum.size() && i < displaySpectrum.size(); ++i)
    {
        displaySpectrum[i] = displaySpectrum[i] * smoothingFactor +
                            currentSpectrum[i] * (1.0f - smoothingFactor);
    }

    repaint();
}

//==============================================================================
// WaveformVisualizer Implementation
//==============================================================================

AdvancedSculptingUI::WaveformVisualizer::WaveformVisualizer(AdvancedSculptingUI& parent)
    : owner(parent)
{
    // Initialize waveform buffer (2 seconds at 48kHz)
    waveformData.setSize(2, 96000);
    waveformData.clear();

    startTimer(50); // 20 Hz update rate
}

AdvancedSculptingUI::WaveformVisualizer::~WaveformVisualizer()
{
    stopTimer();
}

void AdvancedSculptingUI::WaveformVisualizer::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.fillAll(juce::Colour(0xff0a0a0a));

    // Center line
    g.setColour(juce::Colour(0xff2a2a2a));
    g.drawHorizontalLine(bounds.getCentreY(),
                        static_cast<float>(bounds.getX()),
                        static_cast<float>(bounds.getRight()));

    // Waveform
    if (waveformData.getNumSamples() > 0)
    {
        juce::Path waveformPath;

        // Draw stereo waveform (L+R mixed)
        auto* leftChannel = waveformData.getReadPointer(0);
        auto* rightChannel = waveformData.getNumChannels() > 1 ?
                             waveformData.getReadPointer(1) : leftChannel;

        int numSamples = waveformData.getNumSamples();
        int samplesPerPixel = juce::jmax(1, numSamples / bounds.getWidth());

        bool firstPoint = true;
        for (int x = 0; x < bounds.getWidth(); ++x)
        {
            int sampleIndex = x * samplesPerPixel;
            if (sampleIndex >= numSamples)
                break;

            // Find min/max in this pixel's sample range
            float minSample = 0.0f;
            float maxSample = 0.0f;

            for (int s = 0; s < samplesPerPixel && (sampleIndex + s) < numSamples; ++s)
            {
                float sample = (leftChannel[sampleIndex + s] + rightChannel[sampleIndex + s]) * 0.5f;
                minSample = juce::jmin(minSample, sample);
                maxSample = juce::jmax(maxSample, sample);
            }

            float minY = bounds.getCentreY() - minSample * bounds.getHeight() * 0.4f;
            float maxY = bounds.getCentreY() - maxSample * bounds.getHeight() * 0.4f;

            if (firstPoint)
            {
                waveformPath.startNewSubPath(bounds.getX() + x, maxY);
                firstPoint = false;
            }
            else
            {
                waveformPath.lineTo(bounds.getX() + x, maxY);
            }
        }

        // Draw path
        g.setColour(juce::Colour(0xff00ff88));
        g.strokePath(waveformPath, juce::PathStrokeType(1.5f));
    }

    // Border
    g.setColour(juce::Colour(0xff404040));
    g.drawRect(bounds, 1);

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(12.0f, juce::Font::bold));
    g.drawText("Waveform", bounds.getX() + 10, bounds.getY() + 5, 100, 16,
               juce::Justification::left);
}

void AdvancedSculptingUI::WaveformVisualizer::resized()
{
    // Nothing to resize
}

void AdvancedSculptingUI::WaveformVisualizer::updateWaveform(const juce::AudioBuffer<float>& buffer)
{
    // Copy incoming buffer to circular waveform buffer
    int numChannels = juce::jmin(buffer.getNumChannels(), waveformData.getNumChannels());
    int numSamples = buffer.getNumSamples();
    int bufferSize = waveformData.getNumSamples();

    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* src = buffer.getReadPointer(ch);
        auto* dst = waveformData.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            dst[writePosition] = src[i];
            writePosition = (writePosition + 1) % bufferSize;
        }
    }
}

void AdvancedSculptingUI::WaveformVisualizer::timerCallback()
{
    repaint();
}

//==============================================================================
// GranularPanel Implementation
//==============================================================================

AdvancedSculptingUI::GranularPanel::GranularPanel(AdvancedSculptingUI& parent)
    : owner(parent)
{
    // Grain Size (1-200ms)
    grainSizeLabel.setText("Grain Size", juce::dontSendNotification);
    grainSizeLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(grainSizeLabel);

    grainSizeSlider.setRange(1.0, 200.0, 1.0);
    grainSizeSlider.setValue(50.0);
    grainSizeSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    grainSizeSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    grainSizeSlider.setTextValueSuffix(" ms");
    addAndMakeVisible(grainSizeSlider);

    // Grain Density (1-100 grains/s)
    grainDensityLabel.setText("Density", juce::dontSendNotification);
    grainDensityLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(grainDensityLabel);

    grainDensitySlider.setRange(1.0, 100.0, 1.0);
    grainDensitySlider.setValue(20.0);
    grainDensitySlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    grainDensitySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    grainDensitySlider.setTextValueSuffix(" /s");
    addAndMakeVisible(grainDensitySlider);

    // Grain Spray (0-1)
    grainSprayLabel.setText("Spray", juce::dontSendNotification);
    grainSprayLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(grainSprayLabel);

    grainSpraySlider.setRange(0.0, 1.0, 0.01);
    grainSpraySlider.setValue(0.1);
    grainSpraySlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    grainSpraySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    addAndMakeVisible(grainSpraySlider);

    // Grain Pitch (-24 to +24 semitones)
    grainPitchLabel.setText("Pitch", juce::dontSendNotification);
    grainPitchLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(grainPitchLabel);

    grainPitchSlider.setRange(-24.0, 24.0, 1.0);
    grainPitchSlider.setValue(0.0);
    grainPitchSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    grainPitchSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    grainPitchSlider.setTextValueSuffix(" st");
    addAndMakeVisible(grainPitchSlider);

    // Grain Position (0-1)
    grainPositionLabel.setText("Position", juce::dontSendNotification);
    grainPositionLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(grainPositionLabel);

    grainPositionSlider.setRange(0.0, 1.0, 0.001);
    grainPositionSlider.setValue(0.5);
    grainPositionSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    grainPositionSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    addAndMakeVisible(grainPositionSlider);

    // Grain Envelope
    grainEnvelopeLabel.setText("Envelope", juce::dontSendNotification);
    grainEnvelopeLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(grainEnvelopeLabel);

    grainEnvelopeCombo.addItem("Gaussian", 1);
    grainEnvelopeCombo.addItem("Triangle", 2);
    grainEnvelopeCombo.addItem("Hann", 3);
    grainEnvelopeCombo.addItem("Trapezoid", 4);
    grainEnvelopeCombo.setSelectedId(1);
    addAndMakeVisible(grainEnvelopeCombo);

    // Bio-Reactive Toggle
    bioReactiveToggle.setButtonText("Bio-Reactive");
    bioReactiveToggle.setToggleState(false, juce::dontSendNotification);
    addAndMakeVisible(bioReactiveToggle);
}

void AdvancedSculptingUI::GranularPanel::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.setColour(juce::Colour(0xff1a1a1a));
    g.fillRoundedRectangle(bounds.toFloat(), 8.0f);

    // Border
    g.setColour(juce::Colour(0xff404040));
    g.drawRoundedRectangle(bounds.toFloat().reduced(1), 8.0f, 1.0f);

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    g.drawText("Granular Synthesis", bounds.getX() + 15, bounds.getY() + 10, 200, 20,
               juce::Justification::left);
}

void AdvancedSculptingUI::GranularPanel::resized()
{
    auto bounds = getLocalBounds().reduced(15);
    bounds.removeFromTop(35); // Title space

    // 3x2 grid of controls
    int controlSize = 80;
    int spacing = 10;

    auto row1 = bounds.removeFromTop(controlSize + 20);
    auto row2 = bounds.removeFromTop(controlSize + 20);

    // Row 1: Grain Size, Density, Spray
    auto col1 = row1.removeFromLeft((bounds.getWidth() - spacing * 2) / 3);
    row1.removeFromLeft(spacing);
    auto col2 = row1.removeFromLeft((bounds.getWidth() - spacing * 2) / 3);
    row1.removeFromLeft(spacing);
    auto col3 = row1;

    grainSizeLabel.setBounds(col1.removeFromTop(20));
    grainSizeSlider.setBounds(col1);

    grainDensityLabel.setBounds(col2.removeFromTop(20));
    grainDensitySlider.setBounds(col2);

    grainSprayLabel.setBounds(col3.removeFromTop(20));
    grainSpraySlider.setBounds(col3);

    // Row 2: Pitch, Position, Envelope
    col1 = row2.removeFromLeft((bounds.getWidth() - spacing * 2) / 3);
    row2.removeFromLeft(spacing);
    col2 = row2.removeFromLeft((bounds.getWidth() - spacing * 2) / 3);
    row2.removeFromLeft(spacing);
    col3 = row2;

    grainPitchLabel.setBounds(col1.removeFromTop(20));
    grainPitchSlider.setBounds(col1);

    grainPositionLabel.setBounds(col2.removeFromTop(20));
    grainPositionSlider.setBounds(col2);

    grainEnvelopeLabel.setBounds(col3.removeFromTop(20));
    grainEnvelopeCombo.setBounds(col3.removeFromTop(30));

    // Bio-Reactive at bottom
    bounds.removeFromTop(10);
    bioReactiveToggle.setBounds(bounds.removeFromTop(30));
}

//==============================================================================
// SpectralPanel Implementation
//==============================================================================

AdvancedSculptingUI::SpectralPanel::SpectralPanel(AdvancedSculptingUI& parent)
    : owner(parent)
{
    // Mix (0-100%)
    mixLabel.setText("Mix", juce::dontSendNotification);
    mixLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(mixLabel);

    mixSlider.setRange(0.0, 100.0, 1.0);
    mixSlider.setValue(100.0);
    mixSlider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    mixSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    mixSlider.setTextValueSuffix(" %");
    addAndMakeVisible(mixSlider);

    // Parameter 1
    param1Label.setText("Threshold", juce::dontSendNotification);
    param1Label.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(param1Label);

    param1Slider.setRange(0.0, 100.0, 1.0);
    param1Slider.setValue(50.0);
    param1Slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    param1Slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    addAndMakeVisible(param1Slider);

    // Parameter 2
    param2Label.setText("Ratio", juce::dontSendNotification);
    param2Label.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(param2Label);

    param2Slider.setRange(1.0, 20.0, 0.1);
    param2Slider.setValue(4.0);
    param2Slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    param2Slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    addAndMakeVisible(param2Slider);

    // Parameter 3
    param3Label.setText("Attack", juce::dontSendNotification);
    param3Label.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(param3Label);

    param3Slider.setRange(0.1, 500.0, 0.1);
    param3Slider.setValue(10.0);
    param3Slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    param3Slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
    param3Slider.setTextValueSuffix(" ms");
    addAndMakeVisible(param3Slider);

    // Capture button
    captureButton.setButtonText("Capture Spectrum");
    addAndMakeVisible(captureButton);

    // Freeze button
    freezeButton.setButtonText("Freeze");
    addAndMakeVisible(freezeButton);

    // Bio-Reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive");
    bioReactiveToggle.setToggleState(false, juce::dontSendNotification);
    addAndMakeVisible(bioReactiveToggle);
}

void AdvancedSculptingUI::SpectralPanel::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.setColour(juce::Colour(0xff1a1a1a));
    g.fillRoundedRectangle(bounds.toFloat(), 8.0f);

    // Border
    g.setColour(juce::Colour(0xff404040));
    g.drawRoundedRectangle(bounds.toFloat().reduced(1), 8.0f, 1.0f);

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    g.drawText("Spectral Processing", bounds.getX() + 15, bounds.getY() + 10, 200, 20,
               juce::Justification::left);
}

void AdvancedSculptingUI::SpectralPanel::resized()
{
    auto bounds = getLocalBounds().reduced(15);
    bounds.removeFromTop(35); // Title space

    // 2x2 grid of controls
    int controlSize = 70;
    int spacing = 10;

    auto row1 = bounds.removeFromTop(controlSize + 20);
    auto row2 = bounds.removeFromTop(controlSize + 20);

    // Row 1: Mix, Param1
    auto col1 = row1.removeFromLeft((bounds.getWidth() - spacing) / 2);
    row1.removeFromLeft(spacing);
    auto col2 = row1;

    mixLabel.setBounds(col1.removeFromTop(20));
    mixSlider.setBounds(col1);

    param1Label.setBounds(col2.removeFromTop(20));
    param1Slider.setBounds(col2);

    // Row 2: Param2, Param3
    col1 = row2.removeFromLeft((bounds.getWidth() - spacing) / 2);
    row2.removeFromLeft(spacing);
    col2 = row2;

    param2Label.setBounds(col1.removeFromTop(20));
    param2Slider.setBounds(col1);

    param3Label.setBounds(col2.removeFromTop(20));
    param3Slider.setBounds(col2);

    // Buttons at bottom
    bounds.removeFromTop(10);
    auto buttonRow = bounds.removeFromTop(35);
    auto button1 = buttonRow.removeFromLeft((bounds.getWidth() - spacing) / 2);
    buttonRow.removeFromLeft(spacing);

    captureButton.setBounds(button1);
    freezeButton.setBounds(buttonRow);

    bounds.removeFromTop(10);
    bioReactiveToggle.setBounds(bounds.removeFromTop(30));
}

void AdvancedSculptingUI::SpectralPanel::updateForMode(SpectralSculptor::ProcessingMode mode)
{
    // Update parameter labels based on mode
    switch (mode)
    {
        case SpectralSculptor::ProcessingMode::Denoise:
            param1Label.setText("Threshold", juce::dontSendNotification);
            param2Label.setText("Smoothing", juce::dontSendNotification);
            param3Label.setText("Attack", juce::dontSendNotification);
            break;

        case SpectralSculptor::ProcessingMode::Gate:
            param1Label.setText("Threshold", juce::dontSendNotification);
            param2Label.setText("Ratio", juce::dontSendNotification);
            param3Label.setText("Release", juce::dontSendNotification);
            break;

        case SpectralSculptor::ProcessingMode::Enhance:
            param1Label.setText("Amount", juce::dontSendNotification);
            param2Label.setText("Frequency", juce::dontSendNotification);
            param3Label.setText("Q", juce::dontSendNotification);
            break;

        case SpectralSculptor::ProcessingMode::Freeze:
            param1Label.setText("Freeze Rate", juce::dontSendNotification);
            param2Label.setText("Smear", juce::dontSendNotification);
            param3Label.setText("Shimmer", juce::dontSendNotification);
            break;

        case SpectralSculptor::ProcessingMode::Morph:
            param1Label.setText("Morph Amount", juce::dontSendNotification);
            param2Label.setText("Time", juce::dontSendNotification);
            param3Label.setText("Curve", juce::dontSendNotification);
            break;

        case SpectralSculptor::ProcessingMode::Restore:
            param1Label.setText("Amount", juce::dontSendNotification);
            param2Label.setText("Bands", juce::dontSendNotification);
            param3Label.setText("Smoothing", juce::dontSendNotification);
            break;

        default:
            break;
    }
}

//==============================================================================
// BioStatusPanel Implementation
//==============================================================================

AdvancedSculptingUI::BioStatusPanel::BioStatusPanel(AdvancedSculptingUI& parent)
    : owner(parent)
{
    startTimer(50); // 20 Hz animation update
}

AdvancedSculptingUI::BioStatusPanel::~BioStatusPanel()
{
    stopTimer();
}

void AdvancedSculptingUI::BioStatusPanel::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.setColour(juce::Colour(0xff1a1a1a));
    g.fillRoundedRectangle(bounds.toFloat(), 8.0f);

    // Border
    g.setColour(juce::Colour(0xff404040));
    g.drawRoundedRectangle(bounds.toFloat().reduced(1), 8.0f, 1.0f);

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    g.drawText("Bio-Reactive Status", bounds.getX() + 15, bounds.getY() + 10, 200, 20,
               juce::Justification::left);

    auto contentBounds = bounds.reduced(15);
    contentBounds.removeFromTop(35);

    // HRV Bar
    auto hrvSection = contentBounds.removeFromTop(60);
    g.setColour(juce::Colours::white);
    g.setFont(12.0f);
    g.drawText("HRV", hrvSection.getX(), hrvSection.getY(), 50, 20, juce::Justification::left);

    auto hrvBar = hrvSection.removeFromBottom(25).reduced(0, 5);
    g.setColour(juce::Colour(0xff2a2a2a));
    g.fillRoundedRectangle(hrvBar.toFloat(), 4.0f);

    // Animated HRV level
    float hrvWidth = hrvBar.getWidth() * hrvBarAnimation;
    auto hrvFill = hrvBar.removeFromLeft(static_cast<int>(hrvWidth));

    juce::ColourGradient hrvGradient(juce::Colour(0xff3a7bd5), hrvFill.getX(), 0,
                                     juce::Colour(0xff00d2ff), hrvFill.getRight(), 0, false);
    g.setGradientFill(hrvGradient);
    g.fillRoundedRectangle(hrvFill.toFloat(), 4.0f);

    g.setColour(juce::Colours::white);
    g.setFont(10.0f);
    g.drawText(juce::String(static_cast<int>(currentHRV * 100)) + "%",
               hrvBar.getX(), hrvBar.getY() - 18, hrvBar.getWidth(), 15,
               juce::Justification::centredRight);

    contentBounds.removeFromTop(10);

    // Coherence Ring
    auto coherenceSection = contentBounds.removeFromTop(60);
    g.setColour(juce::Colours::white);
    g.setFont(12.0f);
    g.drawText("Coherence", coherenceSection.getX(), coherenceSection.getY(), 100, 20,
               juce::Justification::left);

    auto ringBounds = coherenceSection.removeFromBottom(40).withSizeKeepingCentre(40, 40);

    // Background ring
    g.setColour(juce::Colour(0xff2a2a2a));
    g.drawEllipse(ringBounds.toFloat(), 4.0f);

    // Animated coherence arc
    juce::Path coherenceArc;
    float startAngle = -juce::MathConstants<float>::pi * 0.5f;
    float endAngle = startAngle + coherenceRingAnimation * juce::MathConstants<float>::twoPi;

    coherenceArc.addCentredArc(ringBounds.getCentreX(), ringBounds.getCentreY(),
                              ringBounds.getWidth() * 0.5f, ringBounds.getHeight() * 0.5f,
                              0.0f, startAngle, endAngle, true);

    g.setColour(juce::Colour(0xff00ff88));
    g.strokePath(coherenceArc, juce::PathStrokeType(4.0f));

    g.setColour(juce::Colours::white);
    g.setFont(14.0f);
    g.drawText(juce::String(static_cast<int>(currentCoherence * 100)),
               ringBounds, juce::Justification::centred);

    contentBounds.removeFromTop(10);

    // Stress Indicator
    auto stressSection = contentBounds;
    g.setColour(juce::Colours::white);
    g.setFont(12.0f);
    g.drawText("Stress Level", stressSection.getX(), stressSection.getY(), 100, 20,
               juce::Justification::left);

    auto stressBar = stressSection.removeFromBottom(25).reduced(0, 5);
    g.setColour(juce::Colour(0xff2a2a2a));
    g.fillRoundedRectangle(stressBar.toFloat(), 4.0f);

    float stressWidth = stressBar.getWidth() * currentStress;
    auto stressFill = stressBar.removeFromLeft(static_cast<int>(stressWidth));

    // Stress uses red-yellow-green gradient (inverted)
    juce::Colour stressColour = currentStress < 0.5f ?
                               juce::Colour(0xff00ff88) :
                               juce::Colour(0xffff4444);
    g.setColour(stressColour);
    g.fillRoundedRectangle(stressFill.toFloat(), 4.0f);

    g.setColour(juce::Colours::white);
    g.setFont(10.0f);
    g.drawText(juce::String(static_cast<int>(currentStress * 100)) + "%",
               stressBar.getX(), stressBar.getY() - 18, stressBar.getWidth(), 15,
               juce::Justification::centredRight);
}

void AdvancedSculptingUI::BioStatusPanel::resized()
{
    // Nothing to resize
}

void AdvancedSculptingUI::BioStatusPanel::updateBioData(float hrv, float coherence, float stress)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrv);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stress);
}

void AdvancedSculptingUI::BioStatusPanel::timerCallback()
{
    // Animate HRV bar
    hrvBarAnimation = hrvBarAnimation * 0.9f + currentHRV * 0.1f;

    // Animate coherence ring
    coherenceRingAnimation = coherenceRingAnimation * 0.9f + currentCoherence * 0.1f;

    repaint();
}
