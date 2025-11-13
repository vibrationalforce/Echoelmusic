#include "PluginEditor.h"

//==============================================================================
// Constructor
//==============================================================================

EchoelmusicAudioProcessorEditor::EchoelmusicAudioProcessorEditor (EchoelmusicAudioProcessor& p)
    : AudioProcessorEditor (&p), audioProcessor (p)
{
    // Create simplified UI
    mainUI = std::make_unique<SimpleMainUI>();
    addAndMakeVisible(mainUI.get());

    // Set editor size (will be responsive)
    setSize(1200, 800);
    setResizable(true, true);
    setResizeLimits(800, 600, 1920, 1200);

    // Start timer for real-time updates (30 Hz)
    startTimer(33);
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
    // SimpleMainUI handles all painting
    g.fillAll(juce::Colour(0xff1a1a1f));
}

//==============================================================================
// Resized
//==============================================================================

void EchoelmusicAudioProcessorEditor::resized()
{
    if (mainUI)
        mainUI->setBounds(getLocalBounds());
}

//==============================================================================
// Timer Callback (Real-time Updates)
//==============================================================================

void EchoelmusicAudioProcessorEditor::timerCallback()
{
    // Simple UI handles its own updates
}
