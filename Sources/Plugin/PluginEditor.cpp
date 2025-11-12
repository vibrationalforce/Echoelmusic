#include "PluginEditor.h"

//==============================================================================
// Constructor
//==============================================================================

EchoelmusicAudioProcessorEditor::EchoelmusicAudioProcessorEditor (EchoelmusicAudioProcessor& p)
    : AudioProcessorEditor (&p), audioProcessor (p)
{
    // Set editor size (resizable window)
    setSize (800, 600);
    setResizable (true, true);
    setResizeLimits (600, 450, 1600, 1200);

    //==========================================================================
    // Bio-Data Panel
    //==========================================================================

    bioDataPanel = std::make_unique<BioDataPanel>();
    addAndMakeVisible (bioDataPanel.get());

    //==========================================================================
    // Visualizers
    //==========================================================================

    // TODO: Enable in Phase 2 when Visualization classes are built
    // bioVisualizer = std::make_unique<BioReactiveVisualizer>();
    // addAndMakeVisible (bioVisualizer.get());

    // spectrumAnalyzer = std::make_unique<SpectrumAnalyzer>();
    // addAndMakeVisible (spectrumAnalyzer.get());

    //==========================================================================
    // Parameter Sliders
    //==========================================================================

    // Filter Cutoff
    filterCutoffSlider = std::make_unique<RotarySlider>();
    filterCutoffSlider->setRange (20.0, 20000.0);
    filterCutoffSlider->setSkewFactorFromMidPoint (1000.0);
    filterCutoffSlider->setTextValueSuffix (" Hz");
    addAndMakeVisible (filterCutoffSlider.get());

    filterCutoffLabel = std::make_unique<juce::Label>();
    filterCutoffLabel->setText ("Filter Cutoff", juce::dontSendNotification);
    filterCutoffLabel->setJustificationType (juce::Justification::centred);
    filterCutoffLabel->setColour (juce::Label::textColourId, textColour);
    addAndMakeVisible (filterCutoffLabel.get());

    filterCutoffAttachment = std::make_unique<SliderAttachment>(
        audioProcessor.getAPVTS(),
        "filterCutoff",
        *filterCutoffSlider
    );

    // Resonance
    resonanceSlider = std::make_unique<RotarySlider>();
    resonanceSlider->setRange (0.1, 10.0);
    resonanceSlider->setSkewFactorFromMidPoint (1.0);
    addAndMakeVisible (resonanceSlider.get());

    resonanceLabel = std::make_unique<juce::Label>();
    resonanceLabel->setText ("Resonance", juce::dontSendNotification);
    resonanceLabel->setJustificationType (juce::Justification::centred);
    resonanceLabel->setColour (juce::Label::textColourId, textColour);
    addAndMakeVisible (resonanceLabel.get());

    resonanceAttachment = std::make_unique<SliderAttachment>(
        audioProcessor.getAPVTS(),
        "resonance",
        *resonanceSlider
    );

    // Reverb Mix
    reverbMixSlider = std::make_unique<RotarySlider>();
    reverbMixSlider->setRange (0.0, 1.0);
    reverbMixSlider->setTextValueSuffix (" %");
    reverbMixSlider->setNumDecimalPlacesToDisplay (1);
    addAndMakeVisible (reverbMixSlider.get());

    reverbMixLabel = std::make_unique<juce::Label>();
    reverbMixLabel->setText ("Reverb Mix", juce::dontSendNotification);
    reverbMixLabel->setJustificationType (juce::Justification::centred);
    reverbMixLabel->setColour (juce::Label::textColourId, textColour);
    addAndMakeVisible (reverbMixLabel.get());

    reverbMixAttachment = std::make_unique<SliderAttachment>(
        audioProcessor.getAPVTS(),
        "reverbMix",
        *reverbMixSlider
    );

    // Delay Time
    delayTimeSlider = std::make_unique<RotarySlider>();
    delayTimeSlider->setRange (0.0, 2000.0);
    delayTimeSlider->setTextValueSuffix (" ms");
    addAndMakeVisible (delayTimeSlider.get());

    delayTimeLabel = std::make_unique<juce::Label>();
    delayTimeLabel->setText ("Delay Time", juce::dontSendNotification);
    delayTimeLabel->setJustificationType (juce::Justification::centred);
    delayTimeLabel->setColour (juce::Label::textColourId, textColour);
    addAndMakeVisible (delayTimeLabel.get());

    delayTimeAttachment = std::make_unique<SliderAttachment>(
        audioProcessor.getAPVTS(),
        "delayTime",
        *delayTimeSlider
    );

    // Distortion
    distortionSlider = std::make_unique<RotarySlider>();
    distortionSlider->setRange (0.0, 1.0);
    distortionSlider->setNumDecimalPlacesToDisplay (2);
    addAndMakeVisible (distortionSlider.get());

    distortionLabel = std::make_unique<juce::Label>();
    distortionLabel->setText ("Distortion", juce::dontSendNotification);
    distortionLabel->setJustificationType (juce::Justification::centred);
    distortionLabel->setColour (juce::Label::textColourId, textColour);
    addAndMakeVisible (distortionLabel.get());

    distortionAttachment = std::make_unique<SliderAttachment>(
        audioProcessor.getAPVTS(),
        "distortion",
        *distortionSlider
    );

    // Compression
    compressionSlider = std::make_unique<RotarySlider>();
    compressionSlider->setRange (1.0, 20.0);
    compressionSlider->setTextValueSuffix (":1");
    addAndMakeVisible (compressionSlider.get());

    compressionLabel = std::make_unique<juce::Label>();
    compressionLabel->setText ("Compression", juce::dontSendNotification);
    compressionLabel->setJustificationType (juce::Justification::centred);
    compressionLabel->setColour (juce::Label::textColourId, textColour);
    addAndMakeVisible (compressionLabel.get());

    compressionAttachment = std::make_unique<SliderAttachment>(
        audioProcessor.getAPVTS(),
        "compression",
        *compressionSlider
    );

    //==========================================================================
    // Buttons
    //==========================================================================

    presetButton = std::make_unique<juce::TextButton>("Presets");
    presetButton->setColour (juce::TextButton::buttonColourId, panelColour);
    presetButton->setColour (juce::TextButton::textColourOffId, textColour);
    addAndMakeVisible (presetButton.get());

    aboutButton = std::make_unique<juce::TextButton>("About");
    aboutButton->setColour (juce::TextButton::buttonColourId, panelColour);
    aboutButton->setColour (juce::TextButton::textColourOffId, textColour);
    addAndMakeVisible (aboutButton.get());

    //==========================================================================
    // Load Logo (optional)
    //==========================================================================

    // Logo can be embedded as binary data or loaded from file
    // For now, we'll draw a text logo in paint()

    //==========================================================================
    // Start Timer (30 Hz refresh for bio-data and visualizers)
    //==========================================================================

    startTimer (33); // ~30 FPS
}

EchoelmusicAudioProcessorEditor::~EchoelmusicAudioProcessorEditor()
{
    stopTimer();
}

//==============================================================================
// Paint
//==============================================================================

void EchoelmusicAudioProcessorEditor::paint (juce::Graphics& g)
{
    // Background gradient
    g.fillAll (backgroundColour);

    juce::ColourGradient gradient (
        backgroundColour.brighter (0.1f), 0.0f, 0.0f,
        backgroundColour.darker (0.2f), 0.0f, (float)getHeight(),
        false
    );
    g.setGradientFill (gradient);
    g.fillRect (getLocalBounds());

    //==========================================================================
    // Draw Logo/Title
    //==========================================================================

    g.setColour (accentColour);
    g.setFont (juce::Font ("Helvetica", 32.0f, juce::Font::bold));
    g.drawText ("ECHOELMUSIC", 20, 20, 300, 40, juce::Justification::left);

    g.setColour (textColour.withAlpha (0.7f));
    g.setFont (juce::Font ("Helvetica", 14.0f, juce::Font::plain));
    g.drawText ("Bio-Reactive Audio Plugin", 20, 55, 300, 20, juce::Justification::left);

    //==========================================================================
    // Draw Panel Borders
    //==========================================================================

    g.setColour (accentColour.withAlpha (0.3f));

    // Bio-data panel border
    auto bioDataBounds = bioDataPanel->getBounds().toFloat();
    g.drawRoundedRectangle (bioDataBounds.expanded (2.0f), 8.0f, 2.0f);

    // Visualizer borders
    // TODO: Enable in Phase 2
    // auto bioVisBounds = bioVisualizer->getBounds().toFloat();
    // g.drawRoundedRectangle (bioVisBounds.expanded (2.0f), 8.0f, 2.0f);

    // auto spectrumBounds = spectrumAnalyzer->getBounds().toFloat();
    // g.drawRoundedRectangle (spectrumBounds.expanded (2.0f), 8.0f, 2.0f);

    //==========================================================================
    // Version Info
    //==========================================================================

    g.setColour (textColour.withAlpha (0.3f));
    g.setFont (juce::Font ("Helvetica", 10.0f, juce::Font::plain));
    g.drawText ("v1.0.0 | VST3 • AU • AAX • CLAP",
                getWidth() - 220, getHeight() - 25,
                200, 20,
                juce::Justification::right);
}

//==============================================================================
// Resized
//==============================================================================

void EchoelmusicAudioProcessorEditor::resized()
{
    auto bounds = getLocalBounds();
    const int margin = 10;
    const int topBarHeight = 80;
    const int buttonHeight = 30;
    const int sliderSize = 80;
    const int labelHeight = 20;

    //==========================================================================
    // Top Bar (Logo Area)
    //==========================================================================

    auto topBar = bounds.removeFromTop (topBarHeight);

    // Buttons in top right
    auto buttonArea = topBar.removeFromRight (200).reduced (margin);
    presetButton->setBounds (buttonArea.removeFromTop (buttonHeight));
    buttonArea.removeFromTop (5);
    aboutButton->setBounds (buttonArea.removeFromTop (buttonHeight));

    //==========================================================================
    // Left Side: Bio-Data Panel
    //==========================================================================

    auto leftPanel = bounds.removeFromLeft (250).reduced (margin);
    bioDataPanel->setBounds (leftPanel);

    //==========================================================================
    // Right Side: Visualizers & Parameters
    //==========================================================================

    bounds.reduce (margin, margin);

    // Top: Spectrum Analyzer
    // TODO: Enable in Phase 2
    // auto spectrumArea = bounds.removeFromTop (bounds.getHeight() / 3);
    // spectrumAnalyzer->setBounds (spectrumArea);

    // bounds.removeFromTop (margin);

    // Middle: Bio-Reactive Visualizer
    // auto visualizerArea = bounds.removeFromTop (bounds.getHeight() / 2);
    // bioVisualizer->setBounds (visualizerArea);

    // bounds.removeFromTop (margin);

    //==========================================================================
    // Bottom: Parameter Sliders (2 rows of 3)
    //==========================================================================

    auto sliderArea = bounds;
    const int sliderSpacing = (sliderArea.getWidth() - (sliderSize * 3)) / 4;

    // Row 1
    auto row1 = sliderArea.removeFromTop (sliderSize + labelHeight + 10);
    int x = sliderSpacing;

    // Filter Cutoff
    filterCutoffSlider->setBounds (x, row1.getY(), sliderSize, sliderSize);
    filterCutoffLabel->setBounds (x, row1.getY() + sliderSize + 5, sliderSize, labelHeight);
    x += sliderSize + sliderSpacing;

    // Resonance
    resonanceSlider->setBounds (x, row1.getY(), sliderSize, sliderSize);
    resonanceLabel->setBounds (x, row1.getY() + sliderSize + 5, sliderSize, labelHeight);
    x += sliderSize + sliderSpacing;

    // Reverb Mix
    reverbMixSlider->setBounds (x, row1.getY(), sliderSize, sliderSize);
    reverbMixLabel->setBounds (x, row1.getY() + sliderSize + 5, sliderSize, labelHeight);

    // Row 2
    sliderArea.removeFromTop (10);
    auto row2 = sliderArea;
    x = sliderSpacing;

    // Delay Time
    delayTimeSlider->setBounds (x, row2.getY(), sliderSize, sliderSize);
    delayTimeLabel->setBounds (x, row2.getY() + sliderSize + 5, sliderSize, labelHeight);
    x += sliderSize + sliderSpacing;

    // Distortion
    distortionSlider->setBounds (x, row2.getY(), sliderSize, sliderSize);
    distortionLabel->setBounds (x, row2.getY() + sliderSize + 5, sliderSize, labelHeight);
    x += sliderSize + sliderSpacing;

    // Compression
    compressionSlider->setBounds (x, row2.getY(), sliderSize, sliderSize);
    compressionLabel->setBounds (x, row2.getY() + sliderSize + 5, sliderSize, labelHeight);
}

//==============================================================================
// Timer Callback (Real-time Updates)
//==============================================================================

void EchoelmusicAudioProcessorEditor::timerCallback()
{
    // Get current bio-data from processor
    auto bioData = audioProcessor.getCurrentBioData();

    // Update bio-data panel
    bioDataPanel->update (bioData.hrv, bioData.coherence, bioData.heartRate);

    // Update visualizers
    // TODO: Enable in Phase 2
    // bioVisualizer->updateBioData (bioData.hrv, bioData.coherence);
    // spectrumAnalyzer->updateAudioData (audioProcessor.getSpectrumData());

    // Repaint if needed
    bioDataPanel->repaint();
    // bioVisualizer->repaint();
    // spectrumAnalyzer->repaint();
}

//==============================================================================
// Bio-Data Panel Implementation
//==============================================================================

void EchoelmusicAudioProcessorEditor::BioDataPanel::paint (juce::Graphics& g)
{
    auto bounds = getLocalBounds();
    const int margin = 15;

    // Background
    g.fillAll (juce::Colour (0xff2a2a2a));

    // Title
    g.setColour (juce::Colour (0xff00d4ff));
    g.setFont (juce::Font ("Helvetica", 20.0f, juce::Font::bold));
    g.drawText ("BIO-DATA", margin, margin, bounds.getWidth() - margin * 2, 30,
                juce::Justification::centred);

    int y = 60;
    const int rowHeight = 80;
    const int barHeight = 20;
    const int textHeight = 25;

    //==========================================================================
    // HRV (Heart Rate Variability)
    //==========================================================================

    g.setColour (juce::Colours::white);
    g.setFont (juce::Font ("Helvetica", 16.0f, juce::Font::plain));
    g.drawText ("HRV", margin, y, 100, textHeight, juce::Justification::left);

    g.setFont (juce::Font ("Helvetica", 24.0f, juce::Font::bold));
    g.drawText (juce::String (currentHRV, 2), bounds.getWidth() - 120, y, 100, textHeight,
                juce::Justification::right);

    // HRV Bar
    auto hrvBarBounds = juce::Rectangle<float> (margin, y + textHeight + 5,
                                                  bounds.getWidth() - margin * 2, barHeight);
    g.setColour (juce::Colour (0xff404040));
    g.fillRoundedRectangle (hrvBarBounds, 10.0f);

    // HRV Fill (Color: Blue to Cyan based on value)
    auto hrvColor = juce::Colour::fromHSV (0.55f, 0.8f, juce::jmap (currentHRV, 0.0f, 1.0f, 0.3f, 1.0f), 1.0f);
    g.setColour (hrvColor);
    auto hrvFillBounds = hrvBarBounds.withWidth (hrvBarBounds.getWidth() * currentHRV);
    g.fillRoundedRectangle (hrvFillBounds, 10.0f);

    y += rowHeight;

    //==========================================================================
    // Coherence
    //==========================================================================

    g.setColour (juce::Colours::white);
    g.setFont (juce::Font ("Helvetica", 16.0f, juce::Font::plain));
    g.drawText ("Coherence", margin, y, 150, textHeight, juce::Justification::left);

    g.setFont (juce::Font ("Helvetica", 14.0f, juce::Font::bold));
    g.setColour (getCoherenceColor());
    g.drawText (getCoherenceLevel(), bounds.getWidth() - 120, y, 100, textHeight,
                juce::Justification::right);

    // Coherence Bar
    auto cohBarBounds = juce::Rectangle<float> (margin, y + textHeight + 5,
                                                 bounds.getWidth() - margin * 2, barHeight);
    g.setColour (juce::Colour (0xff404040));
    g.fillRoundedRectangle (cohBarBounds, 10.0f);

    // Coherence Fill
    g.setColour (getCoherenceColor());
    auto cohFillBounds = cohBarBounds.withWidth (cohBarBounds.getWidth() * currentCoherence);
    g.fillRoundedRectangle (cohFillBounds, 10.0f);

    y += rowHeight;

    //==========================================================================
    // Heart Rate
    //==========================================================================

    g.setColour (juce::Colours::white);
    g.setFont (juce::Font ("Helvetica", 16.0f, juce::Font::plain));
    g.drawText ("Heart Rate", margin, y, 150, textHeight, juce::Justification::left);

    g.setFont (juce::Font ("Helvetica", 24.0f, juce::Font::bold));
    g.setColour (juce::Colour (0xffff6b6b));
    g.drawText (juce::String ((int)currentHeartRate) + " BPM",
                bounds.getWidth() - 150, y, 130, textHeight,
                juce::Justification::right);

    // Heart icon (simple circle pulse visualization)
    const float heartSize = 30.0f;
    auto heartBounds = juce::Rectangle<float> (margin, y + textHeight + 10, heartSize, heartSize);

    // Pulsing effect based on heart rate
    float pulseScale = 1.0f + 0.1f * std::sin (juce::Time::getMillisecondCounterHiRes() * 0.001f * currentHeartRate / 60.0f * juce::MathConstants<float>::twoPi);
    auto pulseBounds = heartBounds.withSizeKeepingCentre (heartSize * pulseScale, heartSize * pulseScale);

    g.setColour (juce::Colour (0xffff6b6b).withAlpha (0.8f));
    g.fillEllipse (pulseBounds);

    g.setColour (juce::Colour (0xffff6b6b));
    g.drawEllipse (pulseBounds, 2.0f);

    //==========================================================================
    // Status Indicator
    //==========================================================================

    y += rowHeight + 20;

    g.setColour (juce::Colours::white.withAlpha (0.7f));
    g.setFont (juce::Font ("Helvetica", 12.0f, juce::Font::plain));

    // Connection status
    bool isConnected = (currentHeartRate > 0.0f); // Simple check

    if (isConnected)
    {
        g.setColour (juce::Colour (0xff4caf50));
        g.fillEllipse (margin, y, 10, 10);
        g.setColour (juce::Colours::white);
        g.drawText ("Connected", margin + 15, y - 2, 150, 15, juce::Justification::left);
    }
    else
    {
        g.setColour (juce::Colour (0xffff9800));
        g.fillEllipse (margin, y, 10, 10);
        g.setColour (juce::Colours::white.withAlpha (0.7f));
        g.drawText ("Waiting for bio-data...", margin + 15, y - 2, 150, 15, juce::Justification::left);
    }
}

void EchoelmusicAudioProcessorEditor::BioDataPanel::update (float hrv, float coherence, float heartRate)
{
    currentHRV = hrv;
    currentCoherence = coherence;
    currentHeartRate = heartRate;
}

juce::String EchoelmusicAudioProcessorEditor::BioDataPanel::getCoherenceLevel() const
{
    if (currentCoherence < 0.3f)
        return "Low";
    else if (currentCoherence < 0.5f)
        return "Medium";
    else if (currentCoherence < 0.7f)
        return "Good";
    else if (currentCoherence < 0.85f)
        return "High";
    else
        return "Excellent";
}

juce::Colour EchoelmusicAudioProcessorEditor::BioDataPanel::getCoherenceColor() const
{
    if (currentCoherence < 0.3f)
        return juce::Colour (0xfff44336); // Red
    else if (currentCoherence < 0.5f)
        return juce::Colour (0xffff9800); // Orange
    else if (currentCoherence < 0.7f)
        return juce::Colour (0xffffeb3b); // Yellow
    else if (currentCoherence < 0.85f)
        return juce::Colour (0xff8bc34a); // Light Green
    else
        return juce::Colour (0xff4caf50); // Green
}

//==============================================================================
// Rotary Slider Implementation
//==============================================================================

EchoelmusicAudioProcessorEditor::RotarySlider::RotarySlider()
{
    setSliderStyle (juce::Slider::RotaryHorizontalVerticalDrag);
    setTextBoxStyle (juce::Slider::TextBoxBelow, false, 80, 20);
    setColour (juce::Slider::rotarySliderFillColourId, juce::Colour (0xff00d4ff));
    setColour (juce::Slider::rotarySliderOutlineColourId, juce::Colour (0xff404040));
    setColour (juce::Slider::textBoxTextColourId, juce::Colours::white);
    setColour (juce::Slider::textBoxBackgroundColourId, juce::Colour (0xff1a1a1a));
    setColour (juce::Slider::textBoxOutlineColourId, juce::Colours::transparentBlack);
}

void EchoelmusicAudioProcessorEditor::RotarySlider::paint (juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat().reduced (10.0f);
    auto radius = juce::jmin (bounds.getWidth(), bounds.getHeight()) / 2.0f;
    auto centerX = bounds.getCentreX();
    auto centerY = bounds.getCentreY();
    auto angle = juce::MathConstants<float>::pi * 1.5f +
                 getValue() / (getMaximum() - getMinimum()) * juce::MathConstants<float>::pi * 1.5f;

    // Outer circle (track)
    g.setColour (findColour (juce::Slider::rotarySliderOutlineColourId));
    g.drawEllipse (centerX - radius, centerY - radius, radius * 2.0f, radius * 2.0f, 3.0f);

    // Arc (fill)
    juce::Path arcPath;
    arcPath.addCentredArc (centerX, centerY, radius - 5.0f, radius - 5.0f,
                           0.0f, -juce::MathConstants<float>::pi * 0.75f, angle, true);

    g.setColour (findColour (juce::Slider::rotarySliderFillColourId));
    g.strokePath (arcPath, juce::PathStrokeType (4.0f));

    // Pointer
    juce::Path pointer;
    auto pointerLength = radius * 0.6f;
    auto pointerThickness = 3.0f;
    pointer.addRectangle (-pointerThickness * 0.5f, -radius + 10.0f,
                          pointerThickness, pointerLength);
    pointer.applyTransform (juce::AffineTransform::rotation (angle).translated (centerX, centerY));

    g.setColour (juce::Colours::white);
    g.fillPath (pointer);

    // Center dot
    g.setColour (findColour (juce::Slider::rotarySliderFillColourId));
    g.fillEllipse (centerX - 5.0f, centerY - 5.0f, 10.0f, 10.0f);

    // Value text
    g.setColour (juce::Colours::white);
    g.setFont (juce::Font ("Helvetica", 14.0f, juce::Font::bold));
    auto textBounds = bounds.withTop (bounds.getBottom() - 25.0f);
    g.drawText (getTextFromValue (getValue()), textBounds.toNearestInt(),
                juce::Justification::centred);
}
