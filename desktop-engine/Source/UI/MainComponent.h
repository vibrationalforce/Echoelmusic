// MainComponent.h
// Main UI component that integrates OSC and Audio

#pragma once
#include <JuceHeader.h>
#include "../OSC/OSCManager.h"
#include "../Audio/EnhancedSynthesizer.h"

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

    // Timer (for UI updates + OSC feedback)
    void timerCallback() override;

private:
    // OSC
    std::unique_ptr<OSCManager> oscManager;
    bool oscConnected = false;

    // Audio
    std::unique_ptr<EnhancedSynthesizer> synthesizer;

    // UI Labels
    juce::Label titleLabel;
    juce::Label statusLabel;
    juce::Label heartRateLabel;
    juce::Label hrvLabel;
    juce::Label breathRateLabel;
    juce::Label coherenceLabel;
    juce::Label frequencyLabel;

    // UI Values (thread-safe updates)
    std::atomic<float> displayHeartRate{0.0f};
    std::atomic<float> displayHRV{0.0f};
    std::atomic<float> displayBreathRate{0.0f};
    std::atomic<float> displayCoherence{0.0f};
    std::atomic<float> displayFrequency{220.0f};

    // OSC feedback timing
    int feedbackCounter = 0;
    static constexpr int feedbackInterval = 10;  // Send every 10 timer ticks (~333ms at 30Hz)

    // Setup methods
    void setupOSC();
    void setupUI();
    void sendOSCFeedback();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainComponent)
};
