#include "AdvancedDSPManagerUI.h"

//==============================================================================
// AdvancedDSPManagerUI Implementation
//==============================================================================

AdvancedDSPManagerUI::AdvancedDSPManagerUI()
{
    // Create UI components
    topControlBar = std::make_unique<TopControlBar>(*this);
    addAndMakeVisible(topControlBar.get());

    tabBar = std::make_unique<TabBar>(*this);
    addAndMakeVisible(tabBar.get());

    // Create processor panels
    midSidePanel = std::make_unique<MidSideToneMatchingPanel>(*this);
    addAndMakeVisible(midSidePanel.get());

    humanizerPanel = std::make_unique<AudioHumanizerPanel>(*this);
    addChildComponent(humanizerPanel.get());

    swarmPanel = std::make_unique<SwarmReverbPanel>(*this);
    addChildComponent(swarmPanel.get());

    pitchEditorPanel = std::make_unique<PolyphonicPitchEditorPanel>(*this);
    addChildComponent(pitchEditorPanel.get());

    // Tab change callback
    tabBar->onTabChanged = [this](ProcessorTab tab)
    {
        currentTab = tab;

        // Hide all panels
        midSidePanel->setVisible(false);
        humanizerPanel->setVisible(false);
        swarmPanel->setVisible(false);
        pitchEditorPanel->setVisible(false);

        // Show selected panel
        switch (tab)
        {
            case ProcessorTab::MidSideToneMatching:
                midSidePanel->setVisible(true);
                break;
            case ProcessorTab::AudioHumanizer:
                humanizerPanel->setVisible(true);
                break;
            case ProcessorTab::SwarmReverb:
                swarmPanel->setVisible(true);
                break;
            case ProcessorTab::PolyphonicPitchEditor:
                pitchEditorPanel->setVisible(true);
                break;
        }

        resized();
    };

    // Start timer for real-time updates (30 Hz)
    startTimerHz(30);

    setSize(900, 700);
}

AdvancedDSPManagerUI::~AdvancedDSPManagerUI()
{
    stopTimer();
}

void AdvancedDSPManagerUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
}

void AdvancedDSPManagerUI::paint(juce::Graphics& g)
{
    // Background gradient
    g.fillAll(juce::Colour(0xff1a1a1f));

    auto bounds = getLocalBounds();
    juce::ColourGradient gradient(juce::Colour(0xff1a1a1f), 0.0f, 0.0f,
                                  juce::Colour(0xff0d0d10), 0.0f, static_cast<float>(bounds.getHeight()),
                                  false);
    g.setGradientFill(gradient);
    g.fillRect(bounds);

    // Title
    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(24.0f, juce::Font::bold));
    g.drawText("Advanced DSP Manager", bounds.removeFromTop(60).reduced(20, 10),
               juce::Justification::centredLeft);
}

void AdvancedDSPManagerUI::resized()
{
    auto bounds = getLocalBounds();

    // Top margin for title
    bounds.removeFromTop(60);

    // Top control bar
    topControlBar->setBounds(bounds.removeFromTop(60).reduced(10, 5));

    // Tab bar
    tabBar->setBounds(bounds.removeFromTop(50).reduced(10, 5));

    // Processor panel area
    auto panelBounds = bounds.reduced(10);

    if (midSidePanel->isVisible())
        midSidePanel->setBounds(panelBounds);
    if (humanizerPanel->isVisible())
        humanizerPanel->setBounds(panelBounds);
    if (swarmPanel->isVisible())
        swarmPanel->setBounds(panelBounds);
    if (pitchEditorPanel->isVisible())
        pitchEditorPanel->setBounds(panelBounds);
}

void AdvancedDSPManagerUI::timerCallback()
{
    if (!dspManager)
        return;

    // Update CPU usage
    currentCPUUsage = dspManager->getCPUUsage();

    // Update bio-reactive status
    // (In production, this would come from bio-data feed)

    // Update visible panel
    switch (currentTab)
    {
        case ProcessorTab::MidSideToneMatching:
            midSidePanel->updateFromDSP();
            break;
        case ProcessorTab::AudioHumanizer:
            humanizerPanel->updateFromDSP();
            break;
        case ProcessorTab::SwarmReverb:
            swarmPanel->updateFromDSP();
            break;
        case ProcessorTab::PolyphonicPitchEditor:
            pitchEditorPanel->updateFromDSP();
            break;
    }

    repaint();
}

//==============================================================================
// TopControlBar Implementation
//==============================================================================

AdvancedDSPManagerUI::TopControlBar::TopControlBar(AdvancedDSPManagerUI& parent)
    : owner(parent)
{
    // A/B Comparison buttons
    copyToAButton.setButtonText("Copy to A");
    addAndMakeVisible(copyToAButton);
    copyToAButton.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->copyToA();
    };

    copyToBButton.setButtonText("Copy to B");
    addAndMakeVisible(copyToBButton);
    copyToBButton.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->copyToB();
    };

    toggleABButton.setButtonText("A/B Toggle");
    addAndMakeVisible(toggleABButton);
    toggleABButton.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->toggleAB();
    };

    // Undo/Redo buttons
    undoButton.setButtonText("← Undo");
    addAndMakeVisible(undoButton);
    undoButton.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->undo();
    };

    redoButton.setButtonText("Redo →");
    addAndMakeVisible(redoButton);
    redoButton.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->redo();
    };

    // Processing order combo
    processingOrderCombo.addItem("Serial", 1);
    processingOrderCombo.addItem("Parallel", 2);
    processingOrderCombo.addItem("Selective", 3);
    processingOrderCombo.setSelectedId(1);
    addAndMakeVisible(processingOrderCombo);
    processingOrderCombo.onChange = [&]()
    {
        if (!owner.dspManager)
            return;

        int selected = processingOrderCombo.getSelectedId();
        if (selected == 1)
            owner.dspManager->setProcessingOrder(AdvancedDSPManager::ProcessingOrder::Serial);
        else if (selected == 2)
            owner.dspManager->setProcessingOrder(AdvancedDSPManager::ProcessingOrder::Parallel);
        else if (selected == 3)
            owner.dspManager->setProcessingOrder(AdvancedDSPManager::ProcessingOrder::Selective);
    };

    // CPU label
    cpuLabel.setText("CPU: 0%", juce::dontSendNotification);
    cpuLabel.setColour(juce::Label::textColourId, juce::Colour(0xffe8e8e8));
    addAndMakeVisible(cpuLabel);

    // Bio-reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive");
    bioReactiveToggle.setToggleState(false, juce::dontSendNotification);
    addAndMakeVisible(bioReactiveToggle);
    bioReactiveToggle.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->setBioReactiveEnabled(bioReactiveToggle.getToggleState());
    };
}

void AdvancedDSPManagerUI::TopControlBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));

    // Update CPU label
    cpuLabel.setText("CPU: " + juce::String(owner.currentCPUUsage, 1) + "%",
                     juce::dontSendNotification);

    // Color code CPU usage
    if (owner.currentCPUUsage > 85.0f)
        cpuLabel.setColour(juce::Label::textColourId, juce::Colour(0xffff4444));
    else if (owner.currentCPUUsage > 70.0f)
        cpuLabel.setColour(juce::Label::textColourId, juce::Colour(0xffffaa00));
    else
        cpuLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00ff88));
}

void AdvancedDSPManagerUI::TopControlBar::resized()
{
    auto bounds = getLocalBounds().reduced(10, 5);

    // Left side: A/B comparison
    auto abBounds = bounds.removeFromLeft(300);
    copyToAButton.setBounds(abBounds.removeFromLeft(90));
    abBounds.removeFromLeft(5);
    copyToBButton.setBounds(abBounds.removeFromLeft(90));
    abBounds.removeFromLeft(5);
    toggleABButton.setBounds(abBounds.removeFromLeft(100));

    bounds.removeFromLeft(10);

    // Undo/Redo
    undoButton.setBounds(bounds.removeFromLeft(80));
    bounds.removeFromLeft(5);
    redoButton.setBounds(bounds.removeFromLeft(80));

    bounds.removeFromLeft(10);

    // Processing order
    processingOrderCombo.setBounds(bounds.removeFromLeft(120));

    // Right side: CPU and bio-reactive
    bioReactiveToggle.setBounds(bounds.removeFromRight(120));
    bounds.removeFromRight(10);
    cpuLabel.setBounds(bounds.removeFromRight(100));
}

//==============================================================================
// TabBar Implementation
//==============================================================================

AdvancedDSPManagerUI::TabBar::TabBar(AdvancedDSPManagerUI& parent)
    : owner(parent)
{
    midSideButton.setButtonText("M/S Tone Matching");
    midSideButton.setToggleState(true, juce::dontSendNotification);
    addAndMakeVisible(midSideButton);
    midSideButton.onClick = [&]()
    {
        setCurrentTab(ProcessorTab::MidSideToneMatching);
    };

    humanizerButton.setButtonText("Audio Humanizer");
    addAndMakeVisible(humanizerButton);
    humanizerButton.onClick = [&]()
    {
        setCurrentTab(ProcessorTab::AudioHumanizer);
    };

    swarmButton.setButtonText("Swarm Reverb");
    addAndMakeVisible(swarmButton);
    swarmButton.onClick = [&]()
    {
        setCurrentTab(ProcessorTab::SwarmReverb);
    };

    pitchEditorButton.setButtonText("Pitch Editor");
    addAndMakeVisible(pitchEditorButton);
    pitchEditorButton.onClick = [&]()
    {
        setCurrentTab(ProcessorTab::PolyphonicPitchEditor);
    };
}

void AdvancedDSPManagerUI::TabBar::setCurrentTab(ProcessorTab tab)
{
    currentTab = tab;

    // Update button states
    midSideButton.setToggleState(tab == ProcessorTab::MidSideToneMatching, juce::dontSendNotification);
    humanizerButton.setToggleState(tab == ProcessorTab::AudioHumanizer, juce::dontSendNotification);
    swarmButton.setToggleState(tab == ProcessorTab::SwarmReverb, juce::dontSendNotification);
    pitchEditorButton.setToggleState(tab == ProcessorTab::PolyphonicPitchEditor, juce::dontSendNotification);

    if (onTabChanged)
        onTabChanged(tab);

    repaint();
}

void AdvancedDSPManagerUI::TabBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));
}

void AdvancedDSPManagerUI::TabBar::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    int tabWidth = bounds.getWidth() / 4;

    midSideButton.setBounds(bounds.removeFromLeft(tabWidth).reduced(2));
    humanizerButton.setBounds(bounds.removeFromLeft(tabWidth).reduced(2));
    swarmButton.setBounds(bounds.removeFromLeft(tabWidth).reduced(2));
    pitchEditorButton.setBounds(bounds);
}

//==============================================================================
// MidSideToneMatchingPanel Implementation
//==============================================================================

AdvancedDSPManagerUI::MidSideToneMatchingPanel::MidSideToneMatchingPanel(AdvancedDSPManagerUI& parent)
    : owner(parent)
{
    // Matching strength slider
    matchingStrengthSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    matchingStrengthSlider.setRange(0.0, 1.0, 0.01);
    matchingStrengthSlider.setValue(0.5);
    matchingStrengthSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(matchingStrengthSlider);

    matchingStrengthLabel.setText("Matching Strength", juce::dontSendNotification);
    matchingStrengthLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(matchingStrengthLabel);

    matchingStrengthSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getMidSideToneMatching().setMatchingStrength(
                static_cast<float>(matchingStrengthSlider.getValue()));
    };

    // Mid gain slider
    midGainSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    midGainSlider.setRange(-12.0, 12.0, 0.1);
    midGainSlider.setValue(0.0);
    midGainSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(midGainSlider);

    midGainLabel.setText("Mid Gain (dB)", juce::dontSendNotification);
    midGainLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(midGainLabel);

    // Side gain slider
    sideGainSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    sideGainSlider.setRange(-12.0, 12.0, 0.1);
    sideGainSlider.setValue(0.0);
    sideGainSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(sideGainSlider);

    sideGainLabel.setText("Side Gain (dB)", juce::dontSendNotification);
    sideGainLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(sideGainLabel);

    // Mid width slider
    midWidthSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    midWidthSlider.setRange(0.0, 2.0, 0.01);
    midWidthSlider.setValue(1.0);
    midWidthSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(midWidthSlider);

    midWidthLabel.setText("Stereo Width", juce::dontSendNotification);
    midWidthLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(midWidthLabel);

    // Learn reference button
    learnReferenceButton.setButtonText("Learn Reference Track");
    addAndMakeVisible(learnReferenceButton);
    learnReferenceButton.onClick = [&]()
    {
        // In production, this would open a file chooser and analyze the reference track
        if (owner.dspManager)
        {
            // Placeholder: would load reference audio buffer here
            juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
                "Learn Reference",
                "Load a reference track to analyze its M/S spectral profile.\n\n"
                "In production: file chooser → audio load → analysis → profile storage");
        }
    };

    // Bio-reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive Modulation");
    addAndMakeVisible(bioReactiveToggle);
    bioReactiveToggle.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getMidSideToneMatching().setBioReactiveEnabled(
                bioReactiveToggle.getToggleState());
    };

    // Initialize spectrum arrays
    currentMidSpectrum.resize(32, 0.0f);
    currentSideSpectrum.resize(32, 0.0f);
    referenceMidSpectrum.resize(32, 0.0f);
    referenceSideSpectrum.resize(32, 0.0f);
}

void AdvancedDSPManagerUI::MidSideToneMatchingPanel::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));

    // Draw spectrum visualizers
    auto bounds = getLocalBounds();
    auto spectrumBounds = bounds.removeFromBottom(200).reduced(20);

    g.setColour(juce::Colour(0xff252530));
    g.fillRoundedRectangle(spectrumBounds.toFloat(), 8.0f);

    // Mid spectrum
    auto midSpectrumBounds = spectrumBounds.removeFromLeft(spectrumBounds.getWidth() / 2).reduced(10);
    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(14.0f));
    g.drawText("Mid Spectrum", midSpectrumBounds.removeFromTop(20), juce::Justification::centred);

    // Draw bars
    float barWidth = static_cast<float>(midSpectrumBounds.getWidth()) / 32.0f;
    for (int i = 0; i < 32; ++i)
    {
        float x = midSpectrumBounds.getX() + i * barWidth;
        float height = currentMidSpectrum[i] * midSpectrumBounds.getHeight();

        g.setColour(juce::Colour(0xff00d4ff).withAlpha(0.8f));
        g.fillRect(x, midSpectrumBounds.getBottom() - height, barWidth - 1.0f, height);

        // Reference overlay (red)
        float refHeight = referenceMidSpectrum[i] * midSpectrumBounds.getHeight();
        g.setColour(juce::Colour(0xffff4444).withAlpha(0.4f));
        g.drawRect(x, midSpectrumBounds.getBottom() - refHeight, barWidth - 1.0f, refHeight, 1.0f);
    }

    // Side spectrum
    auto sideSpectrumBounds = spectrumBounds.reduced(10);
    g.setColour(juce::Colour(0xffe8e8e8));
    g.drawText("Side Spectrum", sideSpectrumBounds.removeFromTop(20), juce::Justification::centred);

    for (int i = 0; i < 32; ++i)
    {
        float x = sideSpectrumBounds.getX() + i * barWidth;
        float height = currentSideSpectrum[i] * sideSpectrumBounds.getHeight();

        g.setColour(juce::Colour(0xff00ff88).withAlpha(0.8f));
        g.fillRect(x, sideSpectrumBounds.getBottom() - height, barWidth - 1.0f, height);

        // Reference overlay
        float refHeight = referenceSideSpectrum[i] * sideSpectrumBounds.getHeight();
        g.setColour(juce::Colour(0xffff4444).withAlpha(0.4f));
        g.drawRect(x, sideSpectrumBounds.getBottom() - refHeight, barWidth - 1.0f, refHeight, 1.0f);
    }
}

void AdvancedDSPManagerUI::MidSideToneMatchingPanel::resized()
{
    auto bounds = getLocalBounds().reduced(20);

    // Reserve bottom for spectrum visualizers
    bounds.removeFromBottom(200);

    // Top section: sliders
    auto sliderBounds = bounds.removeFromTop(200);

    int sliderWidth = sliderBounds.getWidth() / 4;

    auto col1 = sliderBounds.removeFromLeft(sliderWidth).reduced(10);
    matchingStrengthLabel.setBounds(col1.removeFromTop(20));
    matchingStrengthSlider.setBounds(col1.removeFromTop(120));

    auto col2 = sliderBounds.removeFromLeft(sliderWidth).reduced(10);
    midGainLabel.setBounds(col2.removeFromTop(20));
    midGainSlider.setBounds(col2.removeFromTop(120));

    auto col3 = sliderBounds.removeFromLeft(sliderWidth).reduced(10);
    sideGainLabel.setBounds(col3.removeFromTop(20));
    sideGainSlider.setBounds(col3.removeFromTop(120));

    auto col4 = sliderBounds.reduced(10);
    midWidthLabel.setBounds(col4.removeFromTop(20));
    midWidthSlider.setBounds(col4.removeFromTop(120));

    // Middle section: buttons
    auto buttonBounds = bounds.removeFromTop(60).reduced(10);
    learnReferenceButton.setBounds(buttonBounds.removeFromLeft(200));
    buttonBounds.removeFromLeft(20);
    bioReactiveToggle.setBounds(buttonBounds.removeFromLeft(200));
}

void AdvancedDSPManagerUI::MidSideToneMatchingPanel::updateFromDSP()
{
    // In production, this would fetch current spectrum data from DSP
    // For now, simulate with random variations
    for (int i = 0; i < 32; ++i)
    {
        currentMidSpectrum[i] = juce::Random::getSystemRandom().nextFloat() * 0.8f;
        currentSideSpectrum[i] = juce::Random::getSystemRandom().nextFloat() * 0.6f;
    }

    repaint();
}

//==============================================================================
// AudioHumanizerPanel Implementation
//==============================================================================

AdvancedDSPManagerUI::AudioHumanizerPanel::AudioHumanizerPanel(AdvancedDSPManagerUI& parent)
    : owner(parent)
{
    // Humanization amount
    humanizationAmountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    humanizationAmountSlider.setRange(0.0, 1.0, 0.01);
    humanizationAmountSlider.setValue(0.5);
    humanizationAmountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(humanizationAmountSlider);

    humanizationAmountLabel.setText("Overall Amount", juce::dontSendNotification);
    humanizationAmountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(humanizationAmountLabel);

    humanizationAmountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setHumanizationAmount(
                static_cast<float>(humanizationAmountSlider.getValue()));
    };

    // Spectral amount
    spectralAmountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    spectralAmountSlider.setRange(0.0, 1.0, 0.01);
    spectralAmountSlider.setValue(0.5);
    spectralAmountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(spectralAmountSlider);

    spectralAmountLabel.setText("Spectral", juce::dontSendNotification);
    spectralAmountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(spectralAmountLabel);

    spectralAmountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setSpectralAmount(
                static_cast<float>(spectralAmountSlider.getValue()));
    };

    // Transient amount
    transientAmountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    transientAmountSlider.setRange(0.0, 1.0, 0.01);
    transientAmountSlider.setValue(0.5);
    transientAmountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(transientAmountSlider);

    transientAmountLabel.setText("Transient", juce::dontSendNotification);
    transientAmountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(transientAmountLabel);

    transientAmountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setTransientAmount(
                static_cast<float>(transientAmountSlider.getValue()));
    };

    // Colour amount
    colourAmountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    colourAmountSlider.setRange(0.0, 1.0, 0.01);
    colourAmountSlider.setValue(0.5);
    colourAmountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(colourAmountSlider);

    colourAmountLabel.setText("Colour", juce::dontSendNotification);
    colourAmountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(colourAmountLabel);

    colourAmountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setColourAmount(
                static_cast<float>(colourAmountSlider.getValue()));
    };

    // Noise amount
    noiseAmountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    noiseAmountSlider.setRange(0.0, 1.0, 0.01);
    noiseAmountSlider.setValue(0.2);
    noiseAmountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(noiseAmountSlider);

    noiseAmountLabel.setText("Noise", juce::dontSendNotification);
    noiseAmountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(noiseAmountLabel);

    noiseAmountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setNoiseAmount(
                static_cast<float>(noiseAmountSlider.getValue()));
    };

    // Smooth amount
    smoothAmountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    smoothAmountSlider.setRange(0.0, 1.0, 0.01);
    smoothAmountSlider.setValue(0.7);
    smoothAmountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(smoothAmountSlider);

    smoothAmountLabel.setText("Smooth", juce::dontSendNotification);
    smoothAmountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(smoothAmountLabel);

    smoothAmountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setSmoothAmount(
                static_cast<float>(smoothAmountSlider.getValue()));
    };

    // Time division combo
    timeDivisionCombo.addItem("16th", 1);
    timeDivisionCombo.addItem("8th", 2);
    timeDivisionCombo.addItem("Quarter", 3);
    timeDivisionCombo.addItem("Half", 4);
    timeDivisionCombo.addItem("Whole", 5);
    timeDivisionCombo.addItem("2-Bar", 6);
    timeDivisionCombo.addItem("4-Bar", 7);
    timeDivisionCombo.setSelectedId(3);
    addAndMakeVisible(timeDivisionCombo);

    timeDivisionLabel.setText("Time Division", juce::dontSendNotification);
    timeDivisionLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(timeDivisionLabel);

    timeDivisionCombo.onChange = [&]()
    {
        if (!owner.dspManager)
            return;

        AudioHumanizer::TimeDivision division = AudioHumanizer::TimeDivision::Quarter;
        switch (timeDivisionCombo.getSelectedId())
        {
            case 1: division = AudioHumanizer::TimeDivision::Sixteenth; break;
            case 2: division = AudioHumanizer::TimeDivision::Eighth; break;
            case 3: division = AudioHumanizer::TimeDivision::Quarter; break;
            case 4: division = AudioHumanizer::TimeDivision::Half; break;
            case 5: division = AudioHumanizer::TimeDivision::Whole; break;
            case 6: division = AudioHumanizer::TimeDivision::TwoBar; break;
            case 7: division = AudioHumanizer::TimeDivision::FourBar; break;
        }

        owner.dspManager->getAudioHumanizer().setTimeDivision(division);
    };

    // Bio-reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive Intensity");
    addAndMakeVisible(bioReactiveToggle);
    bioReactiveToggle.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getAudioHumanizer().setBioReactiveEnabled(
                bioReactiveToggle.getToggleState());
    };
}

void AdvancedDSPManagerUI::AudioHumanizerPanel::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));

    // Draw info panel
    auto bounds = getLocalBounds();
    auto infoBounds = bounds.removeFromBottom(120).reduced(20);

    g.setColour(juce::Colour(0xff252530));
    g.fillRoundedRectangle(infoBounds.toFloat(), 8.0f);

    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(16.0f, juce::Font::bold));
    g.drawText("Audio Humanizer - Organic Movement Engine", infoBounds.removeFromTop(30),
               juce::Justification::centred);

    g.setFont(juce::Font(13.0f));
    g.setColour(juce::Colour(0xffa8a8a8));
    juce::String infoText = "Adds time-sliced organic variations to make audio feel more natural and alive.\n"
                            "Inspired by Rast Sound Naturaliser 2 (August 2025)\n\n"
                            "4 Dimensions: Spectral (frequency) • Transient (timing) • Colour (tone) • Noise (floor)";
    g.drawText(infoText, infoBounds, juce::Justification::centred);
}

void AdvancedDSPManagerUI::AudioHumanizerPanel::resized()
{
    auto bounds = getLocalBounds().reduced(20);

    // Reserve bottom for info panel
    bounds.removeFromBottom(120);

    // Top row: Overall + Time Division
    auto topRow = bounds.removeFromTop(160).reduced(10);
    int topColWidth = topRow.getWidth() / 3;

    auto col1 = topRow.removeFromLeft(topColWidth).reduced(10);
    humanizationAmountLabel.setBounds(col1.removeFromTop(20));
    humanizationAmountSlider.setBounds(col1);

    topRow.removeFromLeft(topColWidth); // Skip middle

    auto col3 = topRow.reduced(10);
    timeDivisionLabel.setBounds(col3.removeFromTop(20));
    timeDivisionCombo.setBounds(col3.removeFromTop(30));
    col3.removeFromTop(10);
    bioReactiveToggle.setBounds(col3.removeFromTop(30));

    // Middle row: 4 dimension sliders
    auto midRow = bounds.removeFromTop(180).reduced(10);
    int sliderWidth = midRow.getWidth() / 4;

    auto dimCol1 = midRow.removeFromLeft(sliderWidth).reduced(10);
    spectralAmountLabel.setBounds(dimCol1.removeFromTop(20));
    spectralAmountSlider.setBounds(dimCol1);

    auto dimCol2 = midRow.removeFromLeft(sliderWidth).reduced(10);
    transientAmountLabel.setBounds(dimCol2.removeFromTop(20));
    transientAmountSlider.setBounds(dimCol2);

    auto dimCol3 = midRow.removeFromLeft(sliderWidth).reduced(10);
    colourAmountLabel.setBounds(dimCol3.removeFromTop(20));
    colourAmountSlider.setBounds(dimCol3);

    auto dimCol4 = midRow.reduced(10);
    noiseAmountLabel.setBounds(dimCol4.removeFromTop(20));
    noiseAmountSlider.setBounds(dimCol4);

    // Bottom row: Smooth slider
    auto bottomRow = bounds.removeFromTop(160).reduced(10);
    int bottomColWidth = bottomRow.getWidth() / 3;
    auto smoothCol = bottomRow.removeFromLeft(bottomColWidth).reduced(10);
    smoothAmountLabel.setBounds(smoothCol.removeFromTop(20));
    smoothAmountSlider.setBounds(smoothCol);
}

void AdvancedDSPManagerUI::AudioHumanizerPanel::updateFromDSP()
{
    // Update UI from DSP state if needed
    repaint();
}

//==============================================================================
// SwarmReverbPanel Implementation
//==============================================================================

AdvancedDSPManagerUI::SwarmReverbPanel::SwarmReverbPanel(AdvancedDSPManagerUI& parent)
    : owner(parent)
{
    // Particle count
    particleCountSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    particleCountSlider.setRange(100, 1000, 10);
    particleCountSlider.setValue(300);
    particleCountSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(particleCountSlider);

    particleCountLabel.setText("Particles", juce::dontSendNotification);
    particleCountLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(particleCountLabel);

    particleCountSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setParticleCount(
                static_cast<int>(particleCountSlider.getValue()));
    };

    // Cohesion
    cohesionSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    cohesionSlider.setRange(0.0, 1.0, 0.01);
    cohesionSlider.setValue(0.5);
    cohesionSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(cohesionSlider);

    cohesionLabel.setText("Cohesion", juce::dontSendNotification);
    cohesionLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(cohesionLabel);

    cohesionSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setCohesion(
                static_cast<float>(cohesionSlider.getValue()));
    };

    // Separation
    separationSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    separationSlider.setRange(0.0, 1.0, 0.01);
    separationSlider.setValue(0.3);
    separationSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(separationSlider);

    separationLabel.setText("Separation", juce::dontSendNotification);
    separationLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(separationLabel);

    separationSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setSeparation(
                static_cast<float>(separationSlider.getValue()));
    };

    // Chaos
    chaosSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    chaosSlider.setRange(0.0, 1.0, 0.01);
    chaosSlider.setValue(0.2);
    chaosSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(chaosSlider);

    chaosLabel.setText("Chaos", juce::dontSendNotification);
    chaosLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(chaosLabel);

    chaosSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setChaos(
                static_cast<float>(chaosSlider.getValue()));
    };

    // Room size
    roomSizeSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    roomSizeSlider.setRange(5.0, 50.0, 0.1);
    roomSizeSlider.setValue(10.0);
    roomSizeSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(roomSizeSlider);

    roomSizeLabel.setText("Room Size (m)", juce::dontSendNotification);
    roomSizeLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(roomSizeLabel);

    roomSizeSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setSize(
                static_cast<float>(roomSizeSlider.getValue()) / 100.0f);
    };

    // Damping
    dampingSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    dampingSlider.setRange(0.0, 1.0, 0.01);
    dampingSlider.setValue(0.5);
    dampingSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(dampingSlider);

    dampingLabel.setText("Damping", juce::dontSendNotification);
    dampingLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(dampingLabel);

    dampingSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setDamping(
                static_cast<float>(dampingSlider.getValue()));
    };

    // Mix
    mixSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    mixSlider.setRange(0.0, 1.0, 0.01);
    mixSlider.setValue(0.3);
    mixSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(mixSlider);

    mixLabel.setText("Mix", juce::dontSendNotification);
    mixLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(mixLabel);

    mixSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setMix(
                static_cast<float>(mixSlider.getValue()));
    };

    // Bio-reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive Chaos");
    addAndMakeVisible(bioReactiveToggle);
    bioReactiveToggle.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getSwarmReverb().setBioReactiveEnabled(
                bioReactiveToggle.getToggleState());
    };

    // Initialize particle visuals
    particleVisuals.resize(100);
    for (auto& p : particleVisuals)
    {
        p.x = juce::Random::getSystemRandom().nextFloat();
        p.y = juce::Random::getSystemRandom().nextFloat();
        p.z = juce::Random::getSystemRandom().nextFloat();
        p.radius = 2.0f + juce::Random::getSystemRandom().nextFloat() * 3.0f;
    }

    startTimerHz(30); // 30 Hz refresh for particle animation
}

AdvancedDSPManagerUI::SwarmReverbPanel::~SwarmReverbPanel()
{
    stopTimer();
}

void AdvancedDSPManagerUI::SwarmReverbPanel::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));

    // Draw 3D particle visualization
    auto bounds = getLocalBounds();
    auto vizBounds = bounds.removeFromRight(350).reduced(20);

    g.setColour(juce::Colour(0xff252530));
    g.fillRoundedRectangle(vizBounds.toFloat(), 8.0f);

    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    auto titleBounds = vizBounds.removeFromTop(30);
    g.drawText("3D Particle Swarm", titleBounds, juce::Justification::centred);

    // Draw particles in pseudo-3D
    auto particleBounds = vizBounds.reduced(10);
    float centerX = particleBounds.getCentreX();
    float centerY = particleBounds.getCentreY();
    float scale = std::min(particleBounds.getWidth(), particleBounds.getHeight()) * 0.4f;

    // Rotate particles
    float cosAngle = std::cos(rotationAngle);
    float sinAngle = std::sin(rotationAngle);

    for (const auto& p : particleVisuals)
    {
        // Rotate around Y axis
        float rotatedX = p.x * cosAngle - p.z * sinAngle;
        float rotatedZ = p.x * sinAngle + p.z * cosAngle;

        // Project to 2D
        float screenX = centerX + rotatedX * scale;
        float screenY = centerY + (p.y - 0.5f) * scale;

        // Depth-based brightness and size
        float depth = (rotatedZ + 1.0f) * 0.5f; // 0 to 1
        float brightness = 0.3f + depth * 0.7f;
        float size = p.radius * (0.5f + depth * 0.5f);

        g.setColour(juce::Colour(0xff00d4ff).withAlpha(brightness));
        g.fillEllipse(screenX - size, screenY - size, size * 2.0f, size * 2.0f);
    }
}

void AdvancedDSPManagerUI::SwarmReverbPanel::resized()
{
    auto bounds = getLocalBounds().reduced(20);

    // Reserve right side for visualization
    bounds.removeFromRight(350);

    // Slider grid (2 columns × 4 rows)
    int sliderWidth = bounds.getWidth() / 2;
    int sliderHeight = bounds.getHeight() / 4;

    // Column 1
    auto col1 = bounds.removeFromLeft(sliderWidth);

    auto row1 = col1.removeFromTop(sliderHeight).reduced(10);
    particleCountLabel.setBounds(row1.removeFromTop(20));
    particleCountSlider.setBounds(row1);

    auto row2 = col1.removeFromTop(sliderHeight).reduced(10);
    cohesionLabel.setBounds(row2.removeFromTop(20));
    cohesionSlider.setBounds(row2);

    auto row3 = col1.removeFromTop(sliderHeight).reduced(10);
    separationLabel.setBounds(row3.removeFromTop(20));
    separationSlider.setBounds(row3);

    auto row4 = col1.reduced(10);
    chaosLabel.setBounds(row4.removeFromTop(20));
    chaosSlider.setBounds(row4);

    // Column 2
    auto col2Row1 = bounds.removeFromTop(sliderHeight).reduced(10);
    roomSizeLabel.setBounds(col2Row1.removeFromTop(20));
    roomSizeSlider.setBounds(col2Row1);

    auto col2Row2 = bounds.removeFromTop(sliderHeight).reduced(10);
    dampingLabel.setBounds(col2Row2.removeFromTop(20));
    dampingSlider.setBounds(col2Row2);

    auto col2Row3 = bounds.removeFromTop(sliderHeight).reduced(10);
    mixLabel.setBounds(col2Row3.removeFromTop(20));
    mixSlider.setBounds(col2Row3);

    auto col2Row4 = bounds.reduced(10);
    bioReactiveToggle.setBounds(col2Row4.removeFromTop(30));
}

void AdvancedDSPManagerUI::SwarmReverbPanel::updateFromDSP()
{
    // Update particle positions (in production, would come from actual DSP)
    repaint();
}

void AdvancedDSPManagerUI::SwarmReverbPanel::timerCallback()
{
    // Animate particles
    rotationAngle += 0.01f;

    // Update particle positions slightly
    for (auto& p : particleVisuals)
    {
        p.x += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * 0.01f;
        p.y += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * 0.01f;
        p.z += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * 0.01f;

        // Keep in bounds
        p.x = juce::jlimit(0.0f, 1.0f, p.x);
        p.y = juce::jlimit(0.0f, 1.0f, p.y);
        p.z = juce::jlimit(0.0f, 1.0f, p.z);
    }

    repaint();
}

//==============================================================================
// PolyphonicPitchEditorPanel Implementation
//==============================================================================

AdvancedDSPManagerUI::PolyphonicPitchEditorPanel::PolyphonicPitchEditorPanel(AdvancedDSPManagerUI& parent)
    : owner(parent)
{
    // Pitch correction strength
    pitchCorrectionStrengthSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    pitchCorrectionStrengthSlider.setRange(0.0, 1.0, 0.01);
    pitchCorrectionStrengthSlider.setValue(0.8);
    pitchCorrectionStrengthSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(pitchCorrectionStrengthSlider);

    pitchCorrectionStrengthLabel.setText("Correction", juce::dontSendNotification);
    pitchCorrectionStrengthLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(pitchCorrectionStrengthLabel);

    pitchCorrectionStrengthSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getPolyphonicPitchEditor().setPitchCorrectionStrength(
                static_cast<float>(pitchCorrectionStrengthSlider.getValue()));
    };

    // Formant preservation
    formantPreservationSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    formantPreservationSlider.setRange(0.0, 1.0, 0.01);
    formantPreservationSlider.setValue(1.0);
    formantPreservationSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(formantPreservationSlider);

    formantPreservationLabel.setText("Formant", juce::dontSendNotification);
    formantPreservationLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(formantPreservationLabel);

    formantPreservationSlider.onValueChange = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getPolyphonicPitchEditor().setFormantPreservationEnabled(
                formantPreservationSlider.getValue() > 50.0);
    };

    // Vibrato correction
    vibratoCorrectionSlider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    vibratoCorrectionSlider.setRange(0.0, 1.0, 0.01);
    vibratoCorrectionSlider.setValue(0.5);
    vibratoCorrectionSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
    addAndMakeVisible(vibratoCorrectionSlider);

    vibratoCorrectionLabel.setText("Vibrato", juce::dontSendNotification);
    vibratoCorrectionLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(vibratoCorrectionLabel);

    // Scale type
    scaleTypeCombo.addItem("Chromatic", 1);
    scaleTypeCombo.addItem("Major", 2);
    scaleTypeCombo.addItem("Minor", 3);
    scaleTypeCombo.addItem("Harmonic Minor", 4);
    scaleTypeCombo.addItem("Melodic Minor", 5);
    scaleTypeCombo.addItem("Pentatonic", 6);
    scaleTypeCombo.addItem("Blues", 7);
    scaleTypeCombo.addItem("Dorian", 8);
    scaleTypeCombo.addItem("Mixolydian", 9);
    scaleTypeCombo.setSelectedId(1);
    addAndMakeVisible(scaleTypeCombo);

    scaleTypeLabel.setText("Scale", juce::dontSendNotification);
    scaleTypeLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(scaleTypeLabel);

    scaleTypeCombo.onChange = [&]()
    {
        if (!owner.dspManager)
            return;

        PolyphonicPitchEditor::ScaleType scale = PolyphonicPitchEditor::ScaleType::Chromatic;
        switch (scaleTypeCombo.getSelectedId())
        {
            case 1: scale = PolyphonicPitchEditor::ScaleType::Chromatic; break;
            case 2: scale = PolyphonicPitchEditor::ScaleType::Major; break;
            case 3: scale = PolyphonicPitchEditor::ScaleType::Minor; break;
            case 4: scale = PolyphonicPitchEditor::ScaleType::HarmonicMinor; break;
            case 5: scale = PolyphonicPitchEditor::ScaleType::MelodicMinor; break;
            case 6: scale = PolyphonicPitchEditor::ScaleType::Pentatonic; break;
            case 7: scale = PolyphonicPitchEditor::ScaleType::Blues; break;
            case 8: scale = PolyphonicPitchEditor::ScaleType::Dorian; break;
            case 9: scale = PolyphonicPitchEditor::ScaleType::Mixolydian; break;
        }

        int rootNote = rootNoteCombo.getSelectedId() - 1;
        owner.dspManager->getPolyphonicPitchEditor().setScale(scale, rootNote);
    };

    // Root note
    rootNoteCombo.addItem("C", 1);
    rootNoteCombo.addItem("C#", 2);
    rootNoteCombo.addItem("D", 3);
    rootNoteCombo.addItem("D#", 4);
    rootNoteCombo.addItem("E", 5);
    rootNoteCombo.addItem("F", 6);
    rootNoteCombo.addItem("F#", 7);
    rootNoteCombo.addItem("G", 8);
    rootNoteCombo.addItem("G#", 9);
    rootNoteCombo.addItem("A", 10);
    rootNoteCombo.addItem("A#", 11);
    rootNoteCombo.addItem("B", 12);
    rootNoteCombo.setSelectedId(1);
    addAndMakeVisible(rootNoteCombo);

    rootNoteLabel.setText("Root", juce::dontSendNotification);
    rootNoteLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(rootNoteLabel);

    // Quantize button
    quantizeButton.setButtonText("Quantize to Scale");
    addAndMakeVisible(quantizeButton);
    quantizeButton.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getPolyphonicPitchEditor().quantizeToScale();
    };

    // Analyze button
    analyzeButton.setButtonText("Analyze Audio");
    addAndMakeVisible(analyzeButton);
    analyzeButton.onClick = [&]()
    {
        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "Analyze Audio",
            "In production: Loads audio buffer → Polyphonic pitch detection (pYIN) → "
            "Note segmentation → Displays in piano roll below");
    };

    // Bio-reactive toggle
    bioReactiveToggle.setButtonText("Bio-Reactive Correction");
    addAndMakeVisible(bioReactiveToggle);
    bioReactiveToggle.onClick = [&]()
    {
        if (owner.dspManager)
            owner.dspManager->getPolyphonicPitchEditor().setBioReactiveEnabled(
                bioReactiveToggle.getToggleState());
    };
}

void AdvancedDSPManagerUI::PolyphonicPitchEditorPanel::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));

    // Draw piano roll / note display area
    auto bounds = getLocalBounds();
    auto noteBounds = bounds.removeFromBottom(250).reduced(20);

    g.setColour(juce::Colour(0xff252530));
    g.fillRoundedRectangle(noteBounds.toFloat(), 8.0f);

    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    auto titleBounds = noteBounds.removeFromTop(30);
    g.drawText("Detected Notes (Piano Roll)", titleBounds, juce::Justification::centred);

    // Draw piano roll grid
    auto rollBounds = noteBounds.reduced(10);

    // Draw horizontal lines for pitches (C1 to C6 = 60 semitones)
    int numPitches = 60;
    float pitchHeight = rollBounds.getHeight() / static_cast<float>(numPitches);

    for (int i = 0; i <= numPitches; ++i)
    {
        float y = rollBounds.getY() + i * pitchHeight;
        g.setColour(juce::Colour(0xff3a3a40).withAlpha(0.5f));
        g.drawHorizontalLine(static_cast<int>(y), rollBounds.getX(), rollBounds.getRight());

        // Highlight octaves (every 12 semitones)
        if (i % 12 == 0)
        {
            g.setColour(juce::Colour(0xff5a5a60));
            g.drawHorizontalLine(static_cast<int>(y), rollBounds.getX(), rollBounds.getRight());
        }
    }

    // Draw vertical time grid
    int numBeats = 16;
    float beatWidth = rollBounds.getWidth() / static_cast<float>(numBeats);
    for (int i = 0; i <= numBeats; ++i)
    {
        float x = rollBounds.getX() + i * beatWidth;
        g.setColour(juce::Colour(0xff3a3a40).withAlpha(0.5f));
        g.drawVerticalLine(static_cast<int>(x), rollBounds.getY(), rollBounds.getBottom());

        // Highlight bars (every 4 beats)
        if (i % 4 == 0)
        {
            g.setColour(juce::Colour(0xff5a5a60));
            g.drawVerticalLine(static_cast<int>(x), rollBounds.getY(), rollBounds.getBottom());
        }
    }

    // Draw detected notes (example/placeholder)
    for (const auto& note : detectedNotes)
    {
        float noteX = rollBounds.getX() + (note.startTime * beatWidth * 4.0f);
        float noteWidth = note.duration * beatWidth * 4.0f;
        float noteY = rollBounds.getBottom() - ((note.pitch - 24.0f) * pitchHeight);
        float noteHeight = pitchHeight * 0.8f;

        if (note.enabled)
            g.setColour(juce::Colour(0xff00d4ff).withAlpha(0.7f));
        else
            g.setColour(juce::Colour(0xff808080).withAlpha(0.3f));

        g.fillRoundedRectangle(noteX, noteY, noteWidth, noteHeight, 2.0f);

        g.setColour(juce::Colour(0xffe8e8e8));
        g.drawRoundedRectangle(noteX, noteY, noteWidth, noteHeight, 2.0f, 1.0f);
    }

    // Show placeholder message if no notes
    if (detectedNotes.empty())
    {
        g.setColour(juce::Colour(0xffa8a8a8));
        g.setFont(juce::Font(13.0f));
        g.drawText("Click 'Analyze Audio' to detect notes", rollBounds,
                   juce::Justification::centred);
    }
}

void AdvancedDSPManagerUI::PolyphonicPitchEditorPanel::resized()
{
    auto bounds = getLocalBounds().reduced(20);

    // Reserve bottom for piano roll
    bounds.removeFromBottom(250);

    // Top section: sliders and controls (2 rows)
    auto row1 = bounds.removeFromTop(180).reduced(10);
    int col1Width = row1.getWidth() / 3;

    auto slider1 = row1.removeFromLeft(col1Width).reduced(10);
    pitchCorrectionStrengthLabel.setBounds(slider1.removeFromTop(20));
    pitchCorrectionStrengthSlider.setBounds(slider1);

    auto slider2 = row1.removeFromLeft(col1Width).reduced(10);
    formantPreservationLabel.setBounds(slider2.removeFromTop(20));
    formantPreservationSlider.setBounds(slider2);

    auto slider3 = row1.reduced(10);
    vibratoCorrectionLabel.setBounds(slider3.removeFromTop(20));
    vibratoCorrectionSlider.setBounds(slider3);

    // Second row: scale controls and buttons
    auto row2 = bounds.removeFromTop(100).reduced(10);

    auto scaleCol = row2.removeFromLeft(150).reduced(5);
    scaleTypeLabel.setBounds(scaleCol.removeFromTop(20));
    scaleTypeCombo.setBounds(scaleCol.removeFromTop(30));

    auto rootCol = row2.removeFromLeft(100).reduced(5);
    rootNoteLabel.setBounds(rootCol.removeFromTop(20));
    rootNoteCombo.setBounds(rootCol.removeFromTop(30));

    row2.removeFromLeft(20);

    auto buttonCol = row2.removeFromLeft(150).reduced(5);
    quantizeButton.setBounds(buttonCol.removeFromTop(35));
    buttonCol.removeFromTop(5);
    analyzeButton.setBounds(buttonCol.removeFromTop(35));

    row2.removeFromLeft(20);
    bioReactiveToggle.setBounds(row2.removeFromLeft(180).removeFromTop(35));
}

void AdvancedDSPManagerUI::PolyphonicPitchEditorPanel::updateFromDSP()
{
    // In production, would fetch detected notes from DSP processor
    // For now, show example notes
    if (detectedNotes.empty())
    {
        detectedNotes.push_back({1, 0.0f, 1.0f, 48.0f, true});
        detectedNotes.push_back({2, 1.0f, 0.5f, 52.0f, true});
        detectedNotes.push_back({3, 1.5f, 0.5f, 55.0f, true});
        detectedNotes.push_back({4, 2.0f, 2.0f, 60.0f, true});
    }

    repaint();
}
