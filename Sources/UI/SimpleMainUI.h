#pragma once

#include <JuceHeader.h>

//==============================================================================
/**
 * @brief Simplified Main UI for Echoelmusic
 *
 * Placeholder UI that compiles and shows basic info
 * TODO: Full responsive UI integration
 */
class SimpleMainUI : public juce::Component
{
public:
    SimpleMainUI()
    {
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Echoelmusic DAW", juce::dontSendNotification);
        titleLabel.setJustificationType(juce::Justification::centred);
        titleLabel.setFont(juce::Font(32.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        addAndMakeVisible(infoLabel);
        infoLabel.setText("80+ Professional Audio Tools\n\nPhase 4F Complete!\n- PhaseAnalyzer\n- StyleAwareMastering\n- EchoSynth/WaveForge/SampleEngine\n\nCross-Platform Responsive UI (In Progress)",
                         juce::dontSendNotification);
        infoLabel.setJustificationType(juce::Justification::centred);
        infoLabel.setFont(juce::Font(16.0f));
        infoLabel.setColour(juce::Label::textColourId, juce::Colours::white);

        setSize(1200, 800);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a1f));
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        titleLabel.setBounds(bounds.removeFromTop(100).reduced(20));
        infoLabel.setBounds(bounds.reduced(40));
    }

    void prepareToPlay(double, int) {}
    void processBlock(juce::AudioBuffer<float>&) {}

private:
    juce::Label titleLabel;
    juce::Label infoLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SimpleMainUI)
};
