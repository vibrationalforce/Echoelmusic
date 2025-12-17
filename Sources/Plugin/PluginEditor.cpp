#include "PluginEditor.h"

//==============================================================================
// Constructor
//==============================================================================

EchoelmusicAudioProcessorEditor::EchoelmusicAudioProcessorEditor (EchoelmusicAudioProcessor& p)
    : AudioProcessorEditor (&p), audioProcessor (p)
{
    // ⭐ NEW: Create professional UI framework (ready for 230K LOC when .cpp files exist)
    createUIComponents();
    wireUIComponents();

    // Set editor size (professional plugin size)
    setSize(1200, 800);
    setResizable(true, true);
    setResizeLimits(800, 600, 1920, 1200);

    // Start timer for real-time updates (60 Hz for smooth UI)
    startTimerHz(60);

    DBG("Echoelmusic Editor: UI framework initialized (5 working panels + SimpleMainUI)");
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
    // Modern dark background
    g.fillAll(juce::Colour(0xff1a1a1f));
}

//==============================================================================
// Resized
//==============================================================================

void EchoelmusicAudioProcessorEditor::resized()
{
    auto bounds = getLocalBounds();

    // Tab bar at top (40px height)
    auto tabArea = bounds.removeFromTop(40);
    const int numTabs = 5;  // Synth, Bio, Creative, Wellness, Main
    const int tabWidth = tabArea.getWidth() / numTabs;

    synthButton.setBounds(tabArea.removeFromLeft(tabWidth));
    bioButton.setBounds(tabArea.removeFromLeft(tabWidth));
    creativeButton.setBounds(tabArea.removeFromLeft(tabWidth));
    wellnessButton.setBounds(tabArea.removeFromLeft(tabWidth));
    mainButton.setBounds(tabArea.removeFromLeft(tabWidth));

    // Content area for panels (remaining space)
    if (synthUI) synthUI->setBounds(bounds);
    if (bioFeedback) bioFeedback->setBounds(bounds);
    if (creativeTools) creativeTools->setBounds(bounds);
    if (wellnessPanel) wellnessPanel->setBounds(bounds);
    if (mainUI) mainUI->setBounds(bounds);
}

//==============================================================================
// UI Component Creation (Framework ready for 230K LOC)
//==============================================================================

void EchoelmusicAudioProcessorEditor::createUIComponents()
{
    // ⭐ HEADER-ONLY UI COMPONENTS (Working ✅)

    // Synthesizer UI
    synthUI = std::make_unique<EchoSynthUI>();
    addChildComponent(*synthUI);

    // Bio-Feedback Dashboard
    bioFeedback = std::make_unique<BioFeedbackDashboard>();
    addChildComponent(*bioFeedback);

    // Creative Tools Panel
    creativeTools = std::make_unique<CreativeToolsPanel>();
    addChildComponent(*creativeTools);

    // Wellness Control Panel
    wellnessPanel = std::make_unique<WellnessControlPanel>();
    addChildComponent(*wellnessPanel);

    // Main UI (SimpleMainUI) - DEFAULT VISIBLE
    mainUI = std::make_unique<SimpleMainUI>();
    addAndMakeVisible(*mainUI);

    // ⭐ SETUP TAB BUTTONS
    addAndMakeVisible(synthButton);
    addAndMakeVisible(bioButton);
    addAndMakeVisible(creativeButton);
    addAndMakeVisible(wellnessButton);
    addAndMakeVisible(mainButton);

    // Wire button clicks
    synthButton.onClick = [this] { switchToPanel(ActivePanel::Synthesizer); };
    bioButton.onClick = [this] { switchToPanel(ActivePanel::BioFeedback); };
    creativeButton.onClick = [this] { switchToPanel(ActivePanel::CreativeTools); };
    wellnessButton.onClick = [this] { switchToPanel(ActivePanel::Wellness); };
    mainButton.onClick = [this] { switchToPanel(ActivePanel::Main); };

    // Set initial button states
    mainButton.setToggleState(true, juce::dontSendNotification);

    DBG("UI Components created: 5 working panels + SimpleMainUI");
}

void EchoelmusicAudioProcessorEditor::wireUIComponents()
{
    // Get DSP Manager from processor
    auto* dspManager = audioProcessor.getAdvancedDSPManager();

    if (!dspManager)
    {
        DBG("WARNING: AdvancedDSPManager not available");
        return;
    }

    // ⭐ FUTURE WIRING (when .cpp files are implemented):
    // - PresetBrowserUI (23K LOC) → dspManager
    // - AdvancedDSPManagerUI (63K LOC) → dspManager
    // - ModulationMatrixUI (17K LOC) → dspManager
    // - ParameterAutomationUI (31K LOC) → dspManager
    // Total: 134K LOC ready to activate

    // Header-only panels are self-contained (no wiring needed)
    DBG("UI framework wired - ready for future component activation");
}

void EchoelmusicAudioProcessorEditor::switchToPanel(ActivePanel panel)
{
    currentPanel = panel;

    // Hide all panels
    if (synthUI) synthUI->setVisible(false);
    if (bioFeedback) bioFeedback->setVisible(false);
    if (creativeTools) creativeTools->setVisible(false);
    if (wellnessPanel) wellnessPanel->setVisible(false);
    if (mainUI) mainUI->setVisible(false);

    // Reset all button states
    synthButton.setToggleState(false, juce::dontSendNotification);
    bioButton.setToggleState(false, juce::dontSendNotification);
    creativeButton.setToggleState(false, juce::dontSendNotification);
    wellnessButton.setToggleState(false, juce::dontSendNotification);
    mainButton.setToggleState(false, juce::dontSendNotification);

    // Show selected panel and activate button
    switch (panel)
    {
        case ActivePanel::Synthesizer:
            if (synthUI) { synthUI->setVisible(true); synthButton.setToggleState(true, juce::dontSendNotification); }
            break;
        case ActivePanel::BioFeedback:
            if (bioFeedback) { bioFeedback->setVisible(true); bioButton.setToggleState(true, juce::dontSendNotification); }
            break;
        case ActivePanel::CreativeTools:
            if (creativeTools) { creativeTools->setVisible(true); creativeButton.setToggleState(true, juce::dontSendNotification); }
            break;
        case ActivePanel::Wellness:
            if (wellnessPanel) { wellnessPanel->setVisible(true); wellnessButton.setToggleState(true, juce::dontSendNotification); }
            break;
        case ActivePanel::Main:
        default:
            if (mainUI) { mainUI->setVisible(true); mainButton.setToggleState(true, juce::dontSendNotification); }
            break;
    }

    resized();
}

//==============================================================================
// Timer Callback (Real-time Updates)
//==============================================================================

void EchoelmusicAudioProcessorEditor::timerCallback()
{
    // Get audio spectrum data from processor (lock-free)
    auto spectrumData = audioProcessor.getSpectrumData();

    // Create temporary audio buffer for visualization
    juce::AudioBuffer<float> tempBuffer(2, 512);
    tempBuffer.clear();

    // Convert spectrum data to fake audio samples for visualization
    for (int ch = 0; ch < 2; ++ch)
    {
        auto* channelData = tempBuffer.getWritePointer(ch);
        for (int i = 0; i < tempBuffer.getNumSamples(); ++i)
        {
            int spectrumIndex = (i * static_cast<int>(spectrumData.size())) / tempBuffer.getNumSamples();
            if (spectrumIndex < static_cast<int>(spectrumData.size()))
                channelData[i] = spectrumData[static_cast<size_t>(spectrumIndex)] * 0.1f;
        }
    }

    // Update visualizers with audio data
    if (mainUI)
        mainUI->processBlock(tempBuffer);
}
