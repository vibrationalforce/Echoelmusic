// MainComponent.cpp
// Implementation of main component

#include "MainComponent.h"

MainComponent::MainComponent()
{
    // Create components
    oscManager = std::make_unique<OSCManager>();
    synthesizer = std::make_unique<BasicSynthesizer>();

    // Setup
    setupOSC();
    setupUI();

    // Start audio
    setAudioChannels(0, 2);  // 0 inputs, 2 outputs

    // Start UI update timer (30 Hz)
    startTimer(33);

    setSize(600, 400);
}

MainComponent::~MainComponent()
{
    stopTimer();
    shutdownAudio();
    oscManager->shutdown();
}

void MainComponent::setupOSC()
{
    // Initialize OSC server on port 8000
    if (oscManager->initialize(8000))
    {
        oscConnected = true;
        DBG("✅ OSC Server started on port 8000");
    }
    else
    {
        oscConnected = false;
        DBG("❌ Failed to start OSC Server");
    }

    // Setup callbacks for biofeedback data
    oscManager->onHeartRateReceived = [this](float bpm)
    {
        synthesizer->setHeartRate(bpm);
        displayHeartRate.store(bpm);
    };

    oscManager->onHRVReceived = [this](float ms)
    {
        synthesizer->setHRV(ms);
        displayHRV.store(ms);
    };

    oscManager->onParameterChanged = [this](juce::String paramName, float value)
    {
        if (paramName == "hrv_coherence")
        {
            synthesizer->setHRVCoherence(value);
            displayCoherence.store(value);
        }
    };

    oscManager->onPitchReceived = [this](float frequency, float confidence)
    {
        synthesizer->setPitch(frequency, confidence);
    };
}

void MainComponent::setupUI()
{
    // Title
    addAndMakeVisible(titleLabel);
    titleLabel.setText("🎵 Echoelmusic Desktop Engine", juce::dontSendNotification);
    titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));
    titleLabel.setJustificationType(juce::Justification::centred);

    // Status
    addAndMakeVisible(statusLabel);
    statusLabel.setText(oscConnected ? "✅ OSC Server: Listening on port 8000" :
                                       "❌ OSC Server: Failed to start",
                        juce::dontSendNotification);
    statusLabel.setJustificationType(juce::Justification::centred);

    // Biofeedback displays
    addAndMakeVisible(heartRateLabel);
    heartRateLabel.setText("♥️ Heart Rate: --", juce::dontSendNotification);
    heartRateLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(hrvLabel);
    hrvLabel.setText("🫀 HRV: --", juce::dontSendNotification);
    hrvLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(coherenceLabel);
    coherenceLabel.setText("🧘 Coherence: --", juce::dontSendNotification);
    coherenceLabel.setFont(juce::Font(18.0f));

    addAndMakeVisible(frequencyLabel);
    frequencyLabel.setText("🎹 Frequency: 220 Hz", juce::dontSendNotification);
    frequencyLabel.setFont(juce::Font(18.0f));
}

void MainComponent::prepareToPlay(int samplesPerBlockExpected, double sampleRate)
{
    synthesizer->prepareToPlay(samplesPerBlockExpected, sampleRate);
}

void MainComponent::getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill)
{
    synthesizer->getNextAudioBlock(bufferToFill);
}

void MainComponent::releaseResources()
{
    synthesizer->releaseResources();
}

void MainComponent::paint(juce::Graphics& g)
{
    g.fillAll(getLookAndFeel().findColour(juce::ResizableWindow::backgroundColourId));
}

void MainComponent::resized()
{
    auto area = getLocalBounds().reduced(20);

    // Title
    titleLabel.setBounds(area.removeFromTop(40));
    area.removeFromTop(10);

    // Status
    statusLabel.setBounds(area.removeFromTop(30));
    area.removeFromTop(30);

    // Biofeedback displays (centered)
    auto displayArea = area.withSizeKeepingCentre(400, 200);

    heartRateLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    hrvLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    coherenceLabel.setBounds(displayArea.removeFromTop(40));
    displayArea.removeFromTop(10);

    frequencyLabel.setBounds(displayArea.removeFromTop(40));
}

void MainComponent::timerCallback()
{
    // Update UI labels (runs on message thread, safe)
    float hr = displayHeartRate.load();
    float hrv = displayHRV.load();
    float coherence = displayCoherence.load();

    if (hr > 0.0f)
    {
        heartRateLabel.setText("♥️ Heart Rate: " + juce::String(hr, 1) + " bpm",
                               juce::dontSendNotification);
    }

    if (hrv > 0.0f)
    {
        hrvLabel.setText("🫀 HRV: " + juce::String(hrv, 1) + " ms",
                         juce::dontSendNotification);
    }

    if (coherence > 0.0f)
    {
        coherenceLabel.setText("🧘 Coherence: " + juce::String(coherence * 100.0f, 1) + "%",
                               juce::dontSendNotification);
    }

    // Calculate frequency from HR
    if (hr > 0.0f)
    {
        float freq = 100.0f + (800.0f - 100.0f) * ((hr - 40.0f) / (200.0f - 40.0f));
        frequencyLabel.setText("🎹 Frequency: " + juce::String(freq, 1) + " Hz",
                               juce::dontSendNotification);
    }
}
