#include "PluginEditor.h"

//==============================================================================
// Constructor
//==============================================================================

EoelAudioProcessorEditor::EoelAudioProcessorEditor (EoelAudioProcessor& p)
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

EoelAudioProcessorEditor::~EoelAudioProcessorEditor()
{
    stopTimer();
}

//==============================================================================
// Paint
//==============================================================================

void EoelAudioProcessorEditor::paint (juce::Graphics& g)
{
    // SimpleMainUI handles all painting
    g.fillAll(juce::Colour(0xff1a1a1f));
}

//==============================================================================
// Resized
//==============================================================================

void EoelAudioProcessorEditor::resized()
{
    if (mainUI)
        mainUI->setBounds(getLocalBounds());
}

//==============================================================================
// Timer Callback (Real-time Updates)
//==============================================================================

void EoelAudioProcessorEditor::timerCallback()
{
    // Get audio spectrum data from processor (lock-free)
    auto spectrumData = audioProcessor.getSpectrumData();

    // Create temporary audio buffer for visualization
    // Note: This is a simplified approach for visualization only
    // In a production system, you'd use a lock-free FIFO for audio data
    juce::AudioBuffer<float> tempBuffer(2, 512);
    tempBuffer.clear();

    // Convert spectrum data to fake audio samples for visualization
    // (In production, you'd pass real audio data via lock-free FIFO)
    for (int ch = 0; ch < 2; ++ch)
    {
        auto* channelData = tempBuffer.getWritePointer(ch);
        for (int i = 0; i < tempBuffer.getNumSamples(); ++i)
        {
            int spectrumIndex = (i * spectrumData.size()) / tempBuffer.getNumSamples();
            if (spectrumIndex < static_cast<int>(spectrumData.size()))
                channelData[i] = spectrumData[spectrumIndex] * 0.1f;  // Scale down
        }
    }

    // Update visualizers with audio data
    if (mainUI)
        mainUI->processBlock(tempBuffer);
}
