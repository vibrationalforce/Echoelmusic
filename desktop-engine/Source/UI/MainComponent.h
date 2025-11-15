// MainComponent.h
// Main UI component that integrates OSC and Audio

#pragma once
#include <JuceHeader.h>
#include "../OSC/OSCManager.h"
#include "../Audio/BasicSynthesizer.h"

class MainComponent : public juce::AudioAppComponent,
                      public juce::Timer
{
public:
    MainComponent();
    ~MainComponent() override;

    // AudioAppComponent
    void prepareToPlay(int samplesPerBlockExpected, double sampleRate) override;
    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) override;
    void releaseResources() override;

    // Component
    void paint(juce::Graphics& g) override;
    void resized() override;

    // Timer (for UI updates)
    void timerCallback() override;

private:
    // OSC
    std::unique_ptr<OSCManager> oscManager;
    bool oscConnected = false;

    // Audio
    std::unique_ptr<BasicSynthesizer> synthesizer;

    // UI Labels
    juce::Label titleLabel;
    juce::Label statusLabel;
    juce::Label heartRateLabel;
    juce::Label hrvLabel;
    juce::Label coherenceLabel;
    juce::Label frequencyLabel;

    // UI Values (thread-safe updates)
    std::atomic<float> displayHeartRate{0.0f};
    std::atomic<float> displayHRV{0.0f};
    std::atomic<float> displayCoherence{0.0f};
    std::atomic<float> displayFrequency{220.0f};

    // Setup methods
    void setupOSC();
    void setupUI();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainComponent)
};
